// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

import {WETH} from "./external/WETH.sol";
import {CErc20} from "./external/CErc20.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset for fvTokens to instantly begin earning yield.
contract Vault is ERC20 {
    using SafeERC20 for ERC20;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The minimum delay in blocks between each harvest.
    /// todo: this should be changeable and we should support harvesting early
    /// maybe just rename to target harvest blocks or something.
    uint256 public constant MIN_HARVEST_DELAY_BLOCKS = 1661;

    /// @notice The address of the Wrapped Ether contract.
    address constant WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice The underlying token for the vault.
    ERC20 public immutable underlying;

    /// @notice Creates a new vault based on an underlying token.
    /// @param _underlying An underlying ERC20 compliant token.
    constructor(ERC20 _underlying)
        ERC20(
            // ex: Fuse DAI Vault
            string(abi.encodePacked("Fuse ", _underlying.name(), " Vault")),
            // ex: fvDAI
            string(abi.encodePacked("fv", _underlying.symbol())),
            // ex: 18
            _underlying.decimals()
        )
    {
        underlying = _underlying;
    }

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful deposit.
    /// @param user The address of the account that deposited into the vault.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event Deposit(address user, uint256 underlyingAmount);

    /// @notice Emitted after a successful withdrawal.
    /// @param user The address of the account that withdrew from the vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event Withdraw(address user, uint256 underlyingAmount);

    /// @notice Emitted after a successful harvest.
    /// @param harvester The address of the account that initiated the harvest.
    /// @param maxLockedProfit The maximum amount of locked profit accrued during the harvest.
    event Harvest(address harvester, uint256 maxLockedProfit);

    /// @notice Emitted after the vault deposits into a cToken contract.
    /// @param pool The address of the cToken contract.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event EnterPool(CErc20 pool, uint256 underlyingAmount);

    /// @notice Emitted after the vault withdraws funds from a cToken contract.
    /// @param pool The address of the cToken contract.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event ExitPool(CErc20 pool, uint256 underlyingAmount);

    /*///////////////////////////////////////////////////////////////
                             VAULT STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice An array of cTokens the Vault holds.
    CErc20[] public depositedPools;

    /// @notice An ordered array of cTokens representing the withdrawal queue.
    CErc20[] public withdrawalQueue;

    // todo: can we pack all this shit into a struct or just have it packed in storage by using smaller int amounts?

    /// @notice The most recent block where a harvest occurred.
    uint256 public lastHarvest;

    /// @notice The max amount of "locked" profit accrued last harvest.
    uint256 public maxLockedProfit;

    /// @notice The total amount of underlying held in deposits (calculated last harvest).
    /// @dev Includes `maxLockedProfit`.
    uint256 public totalDeposited;

    /// @notice A percent value representing part of the total underlying to keep in the vault.
    /// @dev A mantissa where 1e18 represents 100% and 0e18 represents 0%.
    uint256 public targetFloatPercent = 0.01e18;

    /// @notice A percent value value representing part of the total profit to take for fees.
    /// @dev A mantissa where 1e18 represents 100% and 0e18 represents 0%.
    uint256 public feePercentage = 0.02e18;

    /*///////////////////////////////////////////////////////////////
                         USER ACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits an underlying token and mints fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        _mint(msg.sender, (underlyingAmount * 10**decimals) / exchangeRateCurrent());

        // Transfer in underlying tokens from the sender.
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        emit Deposit(msg.sender, underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of vault shares to redeem.
    function withdraw(uint256 amount) external {
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 underlyingAmount = (exchangeRate * amount) / 10**decimals;

        // Burn fvTokens.
        _burn(msg.sender, amount);

        // Pull extra tokens into float from Fuse if necessary.
        if (getFloat() < underlyingAmount) pullIntoFloat(underlyingAmount);

        // Transfer tokens to the caller.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdrawUnderlying(uint256 underlyingAmount) external {
        uint256 exchangeRate = exchangeRateCurrent();

        // Burn fvTokens.
        _burn(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // Pull extra tokens into float from Fuse if necessary.
        if (getFloat() < underlyingAmount) pullIntoFloat(underlyingAmount);

        // Transfer underlying tokens to the sender.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                         SHARE PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current fvToken exchange rate, scaled by 1e18.
    function exchangeRateCurrent() public view returns (uint256) {
        // Total fvToken supply and vault's total balance in underlying tokens.
        uint256 supply = totalSupply;
        uint256 balance = calculateTotalFreeUnderlying();

        // If either the supply or balance is 0, return 1.
        if (supply == 0 || balance == 0) return 10**decimals;
        return (balance * 10**decimals) / supply;
    }

    /*///////////////////////////////////////////////////////////////
                         WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraw an amount of underlying tokens from pools in the withdrawal queue.
    /// @param underlyingAmount The amount of the underlying asset to pull into float.
    function pullIntoFloat(uint256 underlyingAmount) internal {
        for (uint256 i = withdrawalQueue.length - 1; i < withdrawalQueue.length; i--) {
            CErc20 cToken = withdrawalQueue[i];
            // TODO: do we need to do balance checking or can we just withdraw our amount and see if reverts idk
            uint256 balance = cToken.balanceOfUnderlying(address(this));
            // TODO: i dont think this works.
            if (balance >= underlyingAmount) {
                // todo: refactor this to use exitPool?
                cToken.redeemUnderlying(underlyingAmount);
                break;
            } else {
                // todo: refactor this to use exitPool?
                cToken.redeemUnderlying(balance);
                underlyingAmount -= balance;
            }
        }

        // Update the totalDeposited value to account for the new amount.
        // todo: refactor this to use exitPool?
        totalDeposited -= underlyingAmount;
    }

    /*///////////////////////////////////////////////////////////////
                           HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function nextHarvest() public view returns (uint256) {
        // todo: why return block number can't it stay 0? idk
        if (lastHarvest == 0) return block.number;
        return MIN_HARVEST_DELAY_BLOCKS + lastHarvest;
    }

    function harvest() external {
        require(block.number >= nextHarvest());

        uint256 depositBalance;

        // TODO: Optimizations:
        // - Store depositedPools in memory?
        // - Store length on stack?
        // Loop over each pool to add to the total:
        for (uint256 i = 0; i < depositedPools.length; i++) {
            CErc20 pool = depositedPools[i];

            // Add this pool's balance to the total.
            depositBalance += pool.balanceOfUnderlying(address(this));
        }

        // If the current float size is less than the ideal, increase the float value.
        uint256 updatedFloat = (depositBalance * targetFloatPercent) / 1e18;
        if (updatedFloat > underlying.balanceOf(address(this))) pullIntoFloat(updatedFloat);

        // Subtract the current deposited balance from the one set during the last harvest.
        uint256 profit = depositBalance - totalDeposited;

        // Calculate the total fee taken from the profit.
        uint256 fee = (profit * feePercentage) / 1e18;

        // Transfer fvTokens (representing fees) to the rebalancer
        if (fee > 0) {
            _mint(msg.sender, (profit * 10**decimals) / exchangeRateCurrent());
        }

        // Locked profit is the delta between the underlying amount we
        // had last harvest and the newly calculated underlying amount.
        maxLockedProfit = profit;

        // Update totalDeposited to use the freshly computed underlying amount.
        totalDeposited = depositBalance;

        // Set the lastHarvest to this block, as we just triggered a harvest.
        lastHarvest = block.number;

        emit Harvest(msg.sender, maxLockedProfit);
    }

    function setFeePercentage(uint256 newFeePercentage) external {
        feePercentage = newFeePercentage;
    }

    function calculateUnlockedProfit() public view returns (uint256) {
        // TODO: CAP at 1 if block number exceeds next harvest
        uint256 unlockedProfit = block.number >= lastHarvest
            ? maxLockedProfit
            : (maxLockedProfit * (lastHarvest - block.number)) / (nextHarvest() - lastHarvest);
        // TODO: is there a cleaner way to do this?
        return maxLockedProfit - unlockedProfit;
    }

    function getFloat() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function calculateTotalFreeUnderlying() public view returns (uint256) {
        return totalDeposited - calculateUnlockedProfit() + getFloat();
    }

    /*///////////////////////////////////////////////////////////////
                           REBALANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function haveDepositedInto(CErc20 pool) internal view returns (bool) {
        // TODO: Optimizations:
        // - Store depositedPools in memory?
        // - Store length on stack?
        for (uint256 i = 0; i < depositedPools.length; i++) {
            // If we find the pool that we're entering:
            if (depositedPools[i] == pool) {
                // Exit the function early.
                return true;
            }
        }
        return false;
    }

    function enterPool(CErc20 pool, uint256 underlyingAmount) external {
        // If we have not already deposited into the pool:
        if (!haveDepositedInto(pool)) {
            // Push the pool to the depositedPools array.
            depositedPools.push(pool);
        }

        // Identify whether the cToken
        if (pool.isCEther()) {
            WETH(address(underlying)).withdraw(underlyingAmount);
            pool.mint{value: underlyingAmount}();
        } else {
            // Approve the underlying to the pool for minting.
            underlying.safeApprove(address(pool), underlyingAmount);

            // Deposit into the pool and receive cTokens.
            pool.mint(underlyingAmount);
        }

        // Increase the totalDeposited amount to account for new deposits
        totalDeposited += underlyingAmount;

        emit EnterPool(pool, underlyingAmount);
    }

    function exitPool(uint256 poolIndex, uint256 cTokenAmount) external {
        // Get the pool from the depositedPools array.
        CErc20 pool = depositedPools[poolIndex];
        uint256 cTokenBalance = pool.balanceOf(address(this));

        // If we're withdrawing our full balance:
        if (cTokenBalance == cTokenAmount) {
            // TODO: Optimizations:
            // - Store depositedPools in memory?
            // - Store length on stack?
            // Remove the pool we're withdrawing from:
            depositedPools[poolIndex] = depositedPools[depositedPools.length - 1];
            depositedPools.pop();
        }

        // Checkpoint our underlying balance before we withdraw.
        uint256 preRedeemFloat = getFloat();

        if (pool.isCEther()) {
            uint256 balanceBefore = address(this).balance;
            // Withdraw from the pool.
            pool.redeem(cTokenAmount);
            uint256 balanceAfter = address(this).balance;

            WETH(address(underlying)).deposit{value: balanceAfter - balanceBefore}();
        } else {
            pool.redeem(cTokenAmount);
        }

        // Calculate the amount of underlying that we received.
        uint256 underlyingReceived = getFloat() - preRedeemFloat;

        // Reduce totalDeposited by the underlying amount received.
        totalDeposited -= underlyingReceived;

        emit ExitPool(pool, underlyingReceived);
    }

    /// @notice Allows governance to set a new float size.
    /// @dev The new float size is a percentage mantissa scaled by 1e18.
    /// @param newTargetFloatPercent The new target float size.percent
    function setTargetFloatPercent(uint256 newTargetFloatPercent) external {
        targetFloatPercent = newTargetFloatPercent;
    }

    /// @notice Allows the rebalancer to set a new withdrawal queue.
    /// @dev The queue should be in ascending order of priority.
    /// @param newQueue The updated queue (ordered in ascending order of priority).
    function setWithdrawalQueue(CErc20[] memory newQueue) external {
        withdrawalQueue = newQueue;
    }

    receive() external payable {}
}

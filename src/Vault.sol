// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

import {WETH} from "./external/WETH.sol";
import {CErc20} from "./external/CErc20.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset to instantly begin earning yield.
contract Vault is ERC20 {
    using SafeERC20 for ERC20;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token for the vault.
    ERC20 public immutable underlying;

    /// @notice The address of the Wrapped Ether contract.
    address constant WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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

    /// @notice The minimum delay in blocks between each harvest.
    uint256 public minimumHarvestDelay = 1661;

    /// @notice An array of cTokens the Vault holds.
    CErc20[] public depositedPools;

    /// @notice An ordered array of cTokens representing the withdrawal queue.
    CErc20[] public withdrawalQueue;

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

    /// @notice A value set each harvest representing the fee set during the harvest.
    /// @dev This is used to calculate how many fvTokens to mint to the fee holder.
    uint256 public harvestFee;

    /// @notice An address set during deployment that fees are sent to after being claimed.
    // TODO: Come up with name that is better than "feeClaimer".
    address public feeClaimer;

    /// @notice A percent value value representing part of the total profit to take for fees.
    /// @dev A mantissa where 1e18 represents 100% and 0e18 represents 0%.
    uint256 public feePercentage = 0.02e18;

    /*///////////////////////////////////////////////////////////////
                         USER ACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the vault's underlying token to mint fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        _mint(msg.sender, (underlyingAmount * 10**decimals) / exchangeRateCurrent());

        // Transfer in underlying tokens from the sender.
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        emit Deposit(msg.sender, underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of fvTokens to redeem for underlying tokens.
    function withdraw(uint256 amount) external {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // Convert the amount of fvTokens to underlying tokens.
        // This can be done by multiplying the fvTokens by the exchange rate.
        uint256 underlyingAmount = (exchangeRate * amount) / 10**decimals;

        // Burn inputed fvTokens.
        _burn(msg.sender, amount);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        if (underlyingAmount > getFloat()) pullIntoFloat(underlyingAmount);

        // Transfer tokens to the caller.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdrawUnderlying(uint256 underlyingAmount) external {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // Convert underlying tokens to fvTokens and then burn them.
        // This can be done by multiplying the underlying tokens by the exchange rate.
        _burn(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        if (getFloat() < underlyingAmount) pullIntoFloat(underlyingAmount);

        // Transfer underlying tokens to the sender.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                         SHARE PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's balance in underlying tokens.
    function balanceOfUnderlying(address account) external view returns (uint256) {
        return (balanceOf[account] * exchangeRateCurrent()) / 10**decimals;
    }

    /// @notice Returns the current fvToken exchange rate, scaled by 1e18.
    function exchangeRateCurrent() public view returns (uint256) {
        // Store the vault's total underlying balance and fvToken supply.
        uint256 supply = totalSupply;
        uint256 balance = calculateTotalFreeUnderlying();

        // If the supply or balance is zero, return an exchange rate of 1.
        if (supply == 0 || balance == 0) return 10**decimals;

        // Calculate the exchange rate by diving the underlying balance by the fvToken supply.
        return (balance * 10**decimals) / supply;
    }

    /*///////////////////////////////////////////////////////////////
                         WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraw underlying tokens from pools in the withdrawal queue.
    /// @param underlyingAmount The amount of underlying tokens to pull into float.
    function pullIntoFloat(uint256 underlyingAmount) internal {
        // Iterate through the withdrawal queue.
        for (uint256 i = withdrawalQueue.length - 1; i < withdrawalQueue.length; i--) {
            CErc20 cToken = withdrawalQueue[i];

            // Calculate the vault's balance in the cToken contract.
            uint256 balance = cToken.balanceOfUnderlying(address(this));

            // If the balance is greater than the amount to pull, pull the full amount.
            if (balance >= underlyingAmount) {
                exitPool(i, underlyingAmount);
                break;
            } else {
                exitPool(i, underlyingAmount);
                underlyingAmount -= balance;
            }
        }

        // Update the totalDeposited value to account for the new amount.
        totalDeposited -= underlyingAmount;
    }

    /*///////////////////////////////////////////////////////////////
                           HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate the block number of the next harvest.
    function nextHarvest() public view returns (uint256) {
        if (lastHarvest == 0) return block.number;
        return minimumHarvestDelay + lastHarvest;
    }

    /// @notice Trigger a harvest.
    /// This updates the vault's balance in the cToken contracts,
    /// take fees, and update the float.
    function harvest() external {
        // Transfer fvTokens (representing fees) to the fee holder
        uint256 _fee = harvestFee;
        if (_fee > 0) {
            _mint(feeClaimer, (_fee * 10**decimals) / exchangeRateCurrent());
        }

        // Ensure that the harvest does not occur too early.
        require(block.number >= nextHarvest());

        // Set the lastHarvest to this block, as the harvest has just been triggered.
        lastHarvest = block.number;

        // Calculate the vault's total balance in underlying tokens.
        uint256 depositBalance;

        // Loop over each pool to add to the total balance.
        for (uint256 i = 0; i < depositedPools.length; i++) {
            CErc20 pool = depositedPools[i];

            // Add this pool's balance to the total.
            depositBalance += pool.balanceOfUnderlying(address(this));
        }

        // Subtract the current deposited balance from the one set during the last harvest.
        uint256 profit = depositBalance - totalDeposited;

        // Update the totalDeposited amount to use the freshly computed underlying amount.
        totalDeposited = depositBalance;

        // Set the new maximum locked profit.
        maxLockedProfit = profit;

        // TODO: Pull into float without modifying the exchange rate.

        // Calculate the total fee taken from the profit.
        harvestFee = (profit * feePercentage) / 1e18;

        emit Harvest(msg.sender, maxLockedProfit);
    }

    /// @notice Set a new minimum harvest delay.
    function setMinimumHarvestDelay(uint256 delay) public {
        minimumHarvestDelay = delay;
    }

    /// @notice Set a new fee percentage.
    function setFeePercentage(uint256 newFeePercentage) external {
        feePercentage = newFeePercentage;
    }

    /// @notice Set a new fee claimer.
    function setFeeClaimer(address newFeeClaimer) external {
        feeClaimer = newFeeClaimer;
    }

    /// @notice Calculate the profit from the last harvest that is still locked.
    function calculateLockedProfit() public view returns (uint256) {
        // If the harvest has completed, there is no locked profit.
        // Otherwise, we can subtract unlocked profit from the maximum amount of locked profit.
        // Learn more about how we calculate unlocked profit here: https://stackoverflow.com/a/29167238.
        return
            block.number >= nextHarvest()
                ? 0
                : maxLockedProfit - (maxLockedProfit * (block.number - lastHarvest)) / minimumHarvestDelay;
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the vault.
    function getFloat() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /// @notice Calculate the total amount of free underlying tokens.
    function calculateTotalFreeUnderlying() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract the locked profit from the total deposited tokens because it is included in totalDeposited.
        return getFloat() + totalDeposited - calculateLockedProfit();
    }

    /*///////////////////////////////////////////////////////////////
                           REBALANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function haveDepositedInto(CErc20 pool) internal view returns (bool) {
        // Store depositedPools in memory.
        CErc20[] memory _depositedPools = depositedPools;

        // Iterate over deposited pools.
        for (uint256 i = 0; i < _depositedPools.length; i++) {
            // If we find the pool that we're entering:
            if (_depositedPools[i] == pool) {
                // Exit the function early.
                return true;
            }
        }

        // If the pool is not found in the array, return false.
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

    function exitPool(uint256 poolIndex, uint256 cTokenAmount) public {
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

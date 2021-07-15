// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./external/ERC20.sol";
import {CErc20} from "./external/CErc20.sol";

import {LowGasSafeERC20} from "./libraries/LowGasSafeERC20.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset for fvTokens to instantly begin earning yield.
contract Vault is ERC20 {
    using LowGasSafeERC20 for ERC20;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The minimum delay in blocks between each harvest.
    uint256 public constant MIN_HARVEST_DELAY_BLOCKS = 1661;

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
                             VAULT STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice An array of cTokens the Vault holds.
    CErc20[] public depositedPools;

    /// @notice An ordered array of cTokens representing the withdrawal queue.
    CErc20[] public withdrawalQueue;

    /// @notice The most recent block where a harvest occured.
    uint256 public lastHarvest;

    /// @notice The max amount of "locked" profit acrrued last harvest.
    uint256 public maxLockedProfit;

    /// @notice The total amount of underlying held in deposits (calculated last harvest).
    /// @dev Includes `maxLockedProfit`.
    uint256 public totalDeposited;

    /// @notice A percent value representing part of the total underlying to keep in the vault.
    /// @dev A mantissa where 1e18 represents 100% and 0e18 represents 0%.
    uint256 public targetFloatPercent = 0.01e18;

    /*///////////////////////////////////////////////////////////////
                         USER ACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits an underlying token and mints fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        uint256 exchangeRate = exchangeRateCurrent();
        _mint(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // Transfer in underlying tokens from the sender.
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of underlying tokens to burn.
    function withdraw(uint256 amount) external {
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 withdrawalAmount = (amount * 10**decimals) / exchangeRate;

        // Burn fvTokens.
        _burn(msg.sender, amount);

        // Gather tokens from Fuse if needed.
        if (underlying.balanceOf(address(this)) < withdrawalAmount) pullIntoFloat(withdrawalAmount);

        // Transfer tokens to the caller.
        underlying.safeTransfer(msg.sender, withdrawalAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdrawUnderlying(uint256 underlyingAmount) external {
        uint256 exchangeRate = exchangeRateCurrent();

        // Burn fvTokens.
        _burn(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // Gather tokens from Fuse.
        if (underlying.balanceOf(address(this)) < underlyingAmount) pullIntoFloat(underlyingAmount);

        // Transfer underlying tokens to the sender.
        underlying.safeTransfer(msg.sender, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                         SHARE PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current fvToken exchange rate, scaled by 1e18.
    function exchangeRateCurrent() public view returns (uint256) {
        // Total fvToken supply and vault's total balance in underlying tokens.
        uint256 supply = totalSupply();
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
        uint256 updatedFloat = (underlyingAmount * targetFloatPercent) / 1e18;
        for (uint256 i = withdrawalQueue.length - 1; i < withdrawalQueue.length; i--) {
            CErc20 cToken = withdrawalQueue[i];
            // TODO: do we need to do balance checking or can we just withdraw our amount and see if reverts idk
            uint256 balance = cToken.balanceOfUnderlying(address(this));
            // TODO: i dont think this works.
            if (underlyingAmount >= balance + updatedFloat) {
                cToken.redeemUnderlying(underlyingAmount + updatedFloat);
                break;
            } else {
                cToken.redeemUnderlying(balance);
                underlyingAmount -= balance;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                           HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function nextHarvest() public view returns (uint256) {
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
        if (updatedFloat > targetFloatPercent) pullIntoFloat(updatedFloat);

        // Locked profit is the delta between the underlying amount we
        // had last harvest and the newly calculated underlying amount.
        maxLockedProfit = depositBalance - totalDeposited;

        // Update totalDeposited to use the freshly computed underlying amount.
        totalDeposited = depositBalance;

        // Set the lastHarvest to this block, as we just triggered a harvest.
        lastHarvest = block.number;
    }

    function calculateUnlockedProfit() public view returns (uint256) {
        // TODO: CAP at 1 if block numger exceeds next harvest
        uint256 unlockedProfit = block.number >= lastHarvest
            ? maxLockedProfit
            : (maxLockedProfit * (block.number - lastHarvest)) / (nextHarvest() - lastHarvest);
        // TODO: is there a cleaner way to do this?
        return maxLockedProfit - unlockedProfit;
    }

    function calculateTotalFreeUnderlying() public view returns (uint256) {
        return totalDeposited - calculateUnlockedProfit() + underlying.balanceOf(address(this));
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

        // Approve the underlying to the pool for minting.
        underlying.approve(address(pool), underlyingAmount);

        // Deposit into the pool and receive cTokens.
        pool.mint(underlyingAmount);

        // Increase the totalDeposited amount to account for new deposits
        totalDeposited += underlyingAmount;
    }

    function exitPool(CErc20 pool, uint256 cTokenAmount) external {
        // If we're withdrawing our full balance:
        uint256 cTokenBalance = pool.balanceOf(address(this));
        if (cTokenBalance == cTokenAmount) {
            // TODO: Optimizations:
            // - Store depositedPools in memory?
            // - Store length on stack?
            // Remove the pool we're withdrawing from:
            for (uint256 i = 0; i < depositedPools.length; i++) {
                // Once we find the pool that we're removing:
                if (depositedPools[i] == pool) {
                    // Move the last item in the array to the index we want to delete.
                    depositedPools[i] = depositedPools[depositedPools.length - 1];

                    // Remove the last index of the array.
                    depositedPools.pop();
                }
            }
        }

        // Withdraw from the pool.
        pool.redeem(cTokenAmount);
    }

    /// @notice Allows governance to set a new float size.
    /// @dev The new float size is a percentage mantissa scaled by 1e18.
    /// @param newTargteFloatPercent The new target float size.percent
    function setTargetFloatPercent(uint256 newTargteFloatPercent) external {
        targetFloatPercent = newTargteFloatPercent;
    }

    /// @notice Allows the rebalancer to set a new withdrawal queue.
    /// @dev The queue should be in ascending order of priority.
    /// @param newQueue The updated queue (ordered in ascending order of priority).
    function setWithdrawalQueue(CErc20[] memory newQueue) external {
        withdrawalQueue = newQueue;
    }
}

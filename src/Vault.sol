// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./external/ERC20.sol";
import {CErc20} from "./external/CErc20.sol";
import {StringConcat} from "./libraries/StringConcat.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset for fvTokens to instantly begin earning yield.
contract Vault is ERC20 {
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
            StringConcat.concat("Fuse ", _underlying.name(), " Vault"),
            // fvDAI
            StringConcat.concat("fv", _underlying.symbol())
        )
    {
        underlying = _underlying;
    }

    /*///////////////////////////////////////////////////////////////
                             VAULT STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice An array of cTokens the Vault holds.
    CErc20[] public depositedPools;

    /// @notice The most recent block where a harvest occured.
    uint256 public lastHarvestBlock;

    /// @notice The amount of "locked" profit acrrued last harvest.
    uint256 public totalLockedProfit;

    /// @notice The total amount of underlying the vault holds (calculated last harvest).
    /// @dev Includes `totalLockedProfit`.
    uint256 public totalUnderlying;

    /*///////////////////////////////////////////////////////////////
                           HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function nextHarvest() public view returns (uint256) {
        return MIN_HARVEST_DELAY_BLOCKS + lastHarvestBlock;
    }

    function harvest() external {
        require(block.timestamp >= nextHarvest());

        uint256 newUnderlying;

        // TODO: Optimizations:
        // - Store depositedPools in memory?
        // - Store length on stack?
        // Loop over each pool to add to the total:
        for (uint256 i = 0; i < depositedPools.length; i++) {
            CErc20 pool = depositedPools[i];

            // Add this pool's balance to the total.
            newUnderlying += pool.balanceOfUnderlying(address(this));
        }

        // Locked profit is the delta between the underlying amount we
        // had last harvest and the newly calculated underlying amount.
        totalLockedProfit = newUnderlying - totalUnderlying;

        // Update totalUnderlying to use the freshly computed underlying amount.
        totalUnderlying = newUnderlying;

        // Set the lastHarvestBlock to this block, as we just triggered a harvest.
        lastHarvestBlock = block.timestamp;
    }

    function calculateLockedProfit() public view returns (uint256) {
        uint256 maxLockedProfit = totalLockedProfit;
        uint256 unlockedProfit = (maxLockedProfit * block.timestamp) / nextHarvest();
        return maxLockedProfit - unlockedProfit;
    }

    function calculateTotalFreeUnderlying() public view returns (uint256) {
        return totalUnderlying - calculateLockedProfit();
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
}

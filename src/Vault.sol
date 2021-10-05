// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Auth} from "solmate/auth/Auth.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {CToken} from "./external/CToken.sol";
import {VaultFactory} from "./VaultFactory.sol";

/// @title Fuse Vault (fvToken)
/// @author Transmissions11 + JetJadeja
/// @notice Yield bearing token that enables users to swap
/// their underlying asset to instantly begin earning yield.
contract Vault is ERC20, Auth {
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token for the Vault.
    ERC20 public immutable UNDERLYING;

    /// @notice One base unit of the underlying, and hence fvToken.
    /// @dev Will be equal to 10 ** UNDERLYING.decimals() which means
    /// if the token has 18 decimals ONE_WHOLE_UNIT will equal 10**18.
    uint256 public immutable BASE_UNIT;

    /// @notice Creates a new Vault that accepts a specific underlying token.
    /// @param _UNDERLYING An underlying ERC20-compliant token.
    constructor(ERC20 _UNDERLYING)
        ERC20(
            // ex: Fuse DAI Vault
            string(abi.encodePacked("Fuse ", _UNDERLYING.name(), " Vault")),
            // ex: fvDAI
            string(abi.encodePacked("fv", _UNDERLYING.symbol())),
            // ex: 18
            _UNDERLYING.decimals()
        )
        Auth(
            // Set the Vault's owner to
            // the VaultFactory's owner:
            VaultFactory(msg.sender).owner()
        )
    {
        UNDERLYING = _UNDERLYING;

        // TODO: Once we upgrade to 0.8.9 we can use 10**decimals
        // instead which will save an external call and an SLOAD.
        BASE_UNIT = 10**_UNDERLYING.decimals();
    }

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful deposit.
    /// @param user The address that deposited into the Vault.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event Deposit(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted after a successful withdrawal.
    /// @param user The address that withdrew from the Vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event Withdraw(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted after a successful harvest.
    /// @param cToken The cToken that was harvested.
    /// @param lockedProfit The amount of locked profit after the harvest.
    event Harvest(CToken indexed cToken, uint256 lockedProfit);

    /// @notice Emitted after the Vault deposits into a cToken contract.
    /// @param cToken The cToken that was minted.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event EnterPool(CToken indexed cToken, uint256 underlyingAmount);

    /// @notice Emitted after the Vault withdraws funds from a cToken contract.
    /// @param cToken The cToken that was redeemed.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event ExitPool(CToken indexed cToken, uint256 underlyingAmount);

    /// @notice Emitted when harvesting a cToken is enabled.
    /// @param cToken The cToken enabled for harvesting.
    event EnableHarvestingPool(CToken indexed cToken);

    /// @notice Emitted when harvesting a cToken is disabled.
    /// @param cToken The cToken disabled for harvesting.
    event DisableHarvestingPool(CToken indexed cToken);

    /// @notice Emitted when the withdrawal queue is updated.
    /// @param updatedWithdrawalQueue The updated withdrawal queue.
    event WithdrawalQueueUpdated(CToken[] updatedWithdrawalQueue);

    /*///////////////////////////////////////////////////////////////
                         POOL ACCOUNTING STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps cTokens to a boolean representing if harvest can be called with them.
    mapping(CToken => bool) public canBeHarvested;

    /// @notice Maps cTokens to the amount of underlying they were worth last harvest.
    mapping(CToken => uint256) public balanceOfUnderlyingLastHarvest;

    /// @notice The total amount of underlying held in deposits (calculated last harvest).
    /// @dev Includes maxLockedProfit, must be correctly subtracted to compute available/free holdings.
    uint256 public totalDeposited;

    /// @notice The amount of locked profit at the time of the last harvest.
    /// @dev Does not change in-between harvests, instead unlocked profit is computed and subtracted from on the fly.
    uint256 public maxLockedProfit;

    /// @notice The most recent timestamp where a harvest occurred.
    uint256 public lastHarvestTimestamp;

    /*///////////////////////////////////////////////////////////////
                        HARVEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The approximate period in seconds over which locked profits are unlocked.
    /// @dev Cannot be 0 as it opens harvests to sandwich attacks.
    uint256 public profitUnlockDelay = 6 hours;

    /// @notice Set a new profit unlock delay delay.
    /// @param newProfitUnlockDelay The new profit unlock delay.
    function setProfitUnlockDelay(uint256 newProfitUnlockDelay) external requiresAuth {
        // An unlock delay of 0 makes harvests vulnerable to sandwich attacks.
        require(profitUnlockDelay > 0, "DELAY_TOO_LOW");

        // Update the profit unlock delay.
        profitUnlockDelay = newProfitUnlockDelay;
    }

    /*///////////////////////////////////////////////////////////////
                      WITHDRAWAL QUEUE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice An ordered array of cTokens representing the withdrawal queue.
    /// @dev The queue is processed in an ascending order, meaning the last index will be first withdrawn from.
    CToken[] public withdrawalQueue;

    /// @notice Gets the full withdrawal queue.
    /// @return An ordered array of cTokens representing the withdrawal queue.
    /// @dev This is provided because Solidity converts public arrays into index getters,
    /// but we need a way to allow external contracts and users to access the whole array.
    function getWithdrawalQueue() external view returns (CToken[] memory) {
        return withdrawalQueue;
    }

    /// @notice Set a new withdrawal queue.
    /// @param newQueue The updated withdrawal queue.
    function setWithdrawalQueue(CToken[] calldata newQueue) external requiresAuth {
        withdrawalQueue = newQueue;

        emit WithdrawalQueueUpdated(newQueue);
    }

    /// @notice Push a single cToken to front of the withdrawal queue.
    /// @param cToken The cToken to be inserted at the front of the withdrawal queue.
    function pushToWithdrawalQueue(CToken cToken) external requiresAuth {
        // TODO: Optimize SLOADs?

        withdrawalQueue.push(cToken);

        emit WithdrawalQueueUpdated(withdrawalQueue);
    }

    /// @notice Remove the cToken at the tip of the withdrawal queue.
    /// @dev Be careful, another user could push a different cToken than
    /// expected to the queue while a popFromWithdrawalQueue transaction is pending.
    function popFromWithdrawalQueue() external requiresAuth {
        // TODO: Optimize SLOADs?

        withdrawalQueue.pop();

        emit WithdrawalQueueUpdated(withdrawalQueue);
    }

    /// @notice Move the cToken at the tip of the queue to the specified index and delete the tip.
    /// @dev The index specified must be less than current length of the withdrawal queue array.
    function moveTipAndPopFromWithdrawalQueue(uint256 index) external requiresAuth {
        // TODO: Cache withdrawalQueue to optimize extra SLOADs?

        // Ensure the index is actually in the withdrawal queue array.
        require(index < withdrawalQueue.length, "INDEX_OUT_OF_BOUNDS");

        // Copy the last item in the array (the tip) to the index specified.
        withdrawalQueue[index] = withdrawalQueue[withdrawalQueue.length - 1];

        // Remove the now duplicated tip from the array.
        withdrawalQueue.pop();
    }

    /*///////////////////////////////////////////////////////////////
                       TARGET FLOAT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice A percent value representing part of the total underlying to keep in the Vault.
    /// @dev A mantissa where 1e18 represents 100% and 0 represents 0%.
    uint256 public targetFloatPercent = 0.01e18;

    /// @notice Allows governance to set a new float size.
    /// @dev The new float size is a percentage mantissa scaled by 1e18.
    /// @param newTargetFloatPercent The new target float size.percent
    function setTargetFloatPercent(uint256 newTargetFloatPercent) external requiresAuth {
        // A target float percentage over 100% doesn't make sense.
        require(targetFloatPercent <= 1e18, "TARGET_TOO_HIGH");

        // Update the target float percentage.
        targetFloatPercent = newTargetFloatPercent;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the Vault's underlying token to mint fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        // We don't allow depositing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Mint a proportional amount of fvTokens.
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit Deposit(msg.sender, underlyingAmount);

        // Transfer in underlying tokens from the sender.
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);
    }

    /// @notice Withdraws a specific amount of underlying tokens by burning the equivalent amount of fvTokens.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdraw(uint256 underlyingAmount) external {
        // We don't allow withdrawing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Convert underlying tokens to fvTokens and then burn them.
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit Withdraw(msg.sender, underlyingAmount);

        // If the amount is greater than the float, redeem some cTokens.
        // TODO: Optimize double calls to getFloat()? One is also done in totalFreeDeposited.
        if (underlyingAmount > getFloat()) {
            pullIntoFloat(
                // The bare minimum we need for this withdrawal.
                (underlyingAmount - getFloat()) +
                    // The amount needed to reach our target float percentage.
                    (totalFreeDeposited() - underlyingAmount).fmul(targetFloatPercent, 1e18)
            );
        }

        // Transfer underlying tokens to the caller.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);
    }

    /// @notice Burns a specific amount of fvTokens and transfers the equivalent amount of underlying tokens.
    /// @param fvTokenAmount The amount of fvTokens to redeem for underlying tokens.
    function redeem(uint256 fvTokenAmount) external {
        // We don't allow redeeming 0 to prevent emitting a useless event.
        require(fvTokenAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Convert the amount of fvTokens to underlying tokens.
        uint256 underlyingAmount = fvTokenAmount.fmul(exchangeRate(), BASE_UNIT);

        // Burn the provided fvTokens.
        _burn(msg.sender, fvTokenAmount);

        emit Withdraw(msg.sender, underlyingAmount);

        // If the amount is greater than the float, redeem some cTokens.
        // TODO: Optimize double calls to getFloat()? One is also done in totalFreeDeposited.
        if (underlyingAmount > getFloat()) {
            pullIntoFloat(
                // The bare minimum we need for this withdrawal.
                (underlyingAmount - getFloat()) +
                    // The amount needed to reach our target float percentage.
                    (totalFreeDeposited() - underlyingAmount).fmul(targetFloatPercent, 1e18)
            );
        }

        // Transfer underlying tokens to the caller.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's Vault balance in underlying tokens.
    /// @return The user's Vault balance in underlying tokens.
    function underlyingBalanceOf(address account) external view returns (uint256) {
        return balanceOf[account].fmul(exchangeRate(), BASE_UNIT);
    }

    /// @notice Returns the amount of underlying tokens an fvToken can be redeemed for.
    /// @return The amount of underlying tokens an fvToken can be redeemed for.
    function exchangeRate() public view returns (uint256) {
        // If the supply or balance is zero, return an exchange rate of 1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        // Calculate the exchange rate by diving the underlying balance by the fvToken supply.
        return totalFreeDeposited().fdiv(totalSupply, BASE_UNIT);
    }

    /// @notice Calculate the total amount of free underlying tokens the Vault currently holds for depositors.
    /// @return The total amount of free underlying tokens the Vault currently holds for depositors.
    function totalFreeDeposited() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract the locked profit from the totalDeposited because maxLockedProfit is baked into it.
        return getFloat() + (totalDeposited - lockedProfit());
    }

    /// @notice Calculate the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // TODO: Cache SLOADs?
        return
            block.timestamp >= lastHarvestTimestamp + profitUnlockDelay
                ? 0 // If profit unlock delay has passed, there is no locked profit.
                : maxLockedProfit - (maxLockedProfit * (block.timestamp - lastHarvestTimestamp)) / profitUnlockDelay;
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function getFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                           HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Trigger a harvest.
    function harvest(CToken cToken) external {
        // If a non authorized cToken could be harvested a malicious user could
        // construct a fake cToken that over-reports holdings to manipulate share price.
        require(canBeHarvested[cToken], "UNAUTHORIZED_CTOKEN");

        uint256 balanceLastHarvest = balanceOfUnderlyingLastHarvest[cToken];
        uint256 balanceThisHarvest = cToken.balanceOfUnderlying(address(this));

        // Increase/decrease totalDeposited based on the computed profit/loss.
        // We cannot wrap the delta calculation in parenthesis as it would underflow if the cToken registers a loss.
        totalDeposited = totalDeposited + balanceThisHarvest - balanceLastHarvest;

        // Update maximum locked profit to include our balance gained.
        maxLockedProfit = lockedProfit() +
            // Compute our profit (losses are instantly accounted for in totalDeposited)
            balanceThisHarvest >
            balanceLastHarvest
            ? balanceThisHarvest - balanceLastHarvest // Difference from last harvest.
            : 0; // If the cToken registered a net loss we don't have any new profit to lock.

        // Set the lastHarvestTimestamp to the current timestamp, as a harvest was just completed.
        lastHarvestTimestamp = block.number;

        // TODO: Cache SLOAD here?
        emit Harvest(cToken, maxLockedProfit);
    }

    /// @notice Disables harvesting a specific cToken.
    /// @param cToken The cToken to disable harvesting.
    function disableHarvestingPool(CToken cToken) external requiresAuth {
        canBeHarvested[cToken] = false;

        emit EnableHarvestingPool(cToken);
    }

    /*///////////////////////////////////////////////////////////////
                            REBALANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit funds into a cToken.
    function enterPool(CToken cToken, uint256 underlyingAmount) external requiresAuth {
        // Enable harvesting the cToken if it wasn't already.
        if (!canBeHarvested[cToken]) {
            canBeHarvested[cToken] = true;
            emit EnableHarvestingPool(cToken);
        }

        // Exit early if we're not actually depositing anything.
        if (underlyingAmount == 0) return;

        // Without this whenever harvest was next called on this
        // cToken the newly deposited amount would count as profit.
        balanceOfUnderlyingLastHarvest[cToken] += underlyingAmount;

        // Increase the totalDeposited amount to account for the minted cTokens.
        totalDeposited += underlyingAmount;

        emit EnterPool(cToken, underlyingAmount);

        // Approve the underlying to the pool for minting.
        UNDERLYING.safeApprove(address(cToken), underlyingAmount);

        // Deposit into the pool and receive cTokens.
        require(cToken.mint(underlyingAmount) == 0, "MINT_FAILED");
    }

    /// @notice Withdraw funds from a pool.
    /// @dev Exiting a pool will not remove it from the withdrawal queue.
    function exitPool(CToken cToken, uint256 underlyingAmount) external requiresAuth {
        // Decrease the totalDeposited amount to account for the redeemed cTokens.
        totalDeposited -= underlyingAmount;

        // Without this whenever harvest was next called on this
        // cToken the withdrawn amount would be count as a loss.
        balanceOfUnderlyingLastHarvest[cToken] -= underlyingAmount;

        emit ExitPool(cToken, underlyingAmount);

        // Redeem the right amount of cTokens to get us underlyingAmount.
        require(cToken.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");
    }

    /*///////////////////////////////////////////////////////////////
                          FLOAT MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraw underlying tokens from cTokens in the withdrawal queue.
    /// @param underlyingAmount The amount of underlying tokens to pull into float.
    function pullIntoFloat(uint256 underlyingAmount) internal {
        // TODO: Is there reentrancy here?
        // TODO: Cache variables to optimize SLOADs.

        uint256 amountLeftToPull = underlyingAmount;

        // We iterate in reverse as the withdrawalQueue is sorted in ascending order.
        for (uint256 i = withdrawalQueue.length - 1; i >= 0; i--) {
            CToken cToken = withdrawalQueue[i];

            // Calculate the Vault's balance in the cToken contract.
            uint256 balance = cToken.balanceOfUnderlying(address(this));

            if (amountLeftToPull > balance) {
                // If this cToken's balance isn't enough to cover the amount
                // we need to pull, withdraw everything we can and keep looping.
                emit ExitPool(cToken, balance);
                require(cToken.redeemUnderlying(balance) == 0, "REDEEM_FAILED");

                // Without this whenever harvest was next called on this
                // cToken the withdrawn amount would be count as a loss.
                balanceOfUnderlyingLastHarvest[cToken] -= balance;

                // We've depleted this cToken, remove it from the queue.
                // TODO: Modifying the array while we're looping over it might break stuff?
                // TODO: It also might just be more efficient to pop a copy in memory and then commit the update in a big chunk.
                withdrawalQueue.pop();

                amountLeftToPull -= balance;
            } else {
                // This cToken has enough to cover the amount we need to pull
                // we need to pull, withdraw only as much as we need and break.
                emit ExitPool(cToken, amountLeftToPull);
                require(cToken.redeemUnderlying(amountLeftToPull) == 0, "REDEEM_FAILED");

                // Without this whenever harvest was next called on this
                // cToken the withdrawn amount would be count as a loss.
                balanceOfUnderlyingLastHarvest[cToken] -= amountLeftToPull;

                // If we depleted the cToken, remove it from the queue.
                // TODO: Modifying the array while we're looping over it might break stuff?
                // TODO: It also might just be more efficient to pop a copy in memory and then commit the update in a big chunk.
                if (amountLeftToPull == balance) withdrawalQueue.pop();

                amountLeftToPull = 0;

                break;
            }
        }

        // If even after looping over the whole queue there is not enough to pull
        // the underlyingAmount, we just revert and let the user know via an error.
        require(amountLeftToPull == 0, "NOT_ENOUGH_FUNDS_IN_QUEUE");

        // Decrease the totalDeposited amount to account for the redeemed cTokens.
        totalDeposited -= underlyingAmount;

        emit WithdrawalQueueUpdated(withdrawalQueue);
    }
}

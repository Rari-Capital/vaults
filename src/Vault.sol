// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Auth} from "solmate/auth/Auth.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {SafeCastLib} from "./libraries/SafeCastLib.sol";
import {Strategy, ERC20Strategy, ETHStrategy} from "./interfaces/Strategy.sol";

import {VaultFactory} from "./VaultFactory.sol";

/// @title Rari Vault (rvToken)
/// @author Transmissions11 + JetJadeja
/// @notice Minimalist yield aggregator designed to support any ERC20 token.
contract Vault is ERC20, Auth {
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point arithmetic.
    uint256 public immutable BASE_UNIT;

    /// @notice Creates a new Vault that accepts a specific underlying token.
    /// @param _UNDERLYING The ERC20 compliant token the Vault should accept.
    constructor(ERC20 _UNDERLYING)
        ERC20(
            // ex: Rari Dai Stablecoin Vault
            string(abi.encodePacked("Rari ", _UNDERLYING.name(), " Vault")),
            // ex: rvDAI
            string(abi.encodePacked("rv", _UNDERLYING.symbol())),
            // ex: 18
            _UNDERLYING.decimals()
        )
        Auth(VaultFactory(msg.sender).owner(), VaultFactory(msg.sender).authority())
    {
        UNDERLYING = _UNDERLYING;

        BASE_UNIT = 10**decimals;
    }

    /*///////////////////////////////////////////////////////////////
                           FEE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The percentage of profit recognized each harvest to reserve as fees.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public feePercent = 0.1e18;

    /// @notice Emitted when the fee percentage is updated.
    /// @param newFeePercent The updated fee percentage.
    event FeePercentUpdated(uint256 newFeePercent);

    /// @notice Set a new fee percentage.
    /// @param newFeePercent The new fee percentage.
    function setFeePercent(uint256 newFeePercent) external requiresAuth {
        // A fee percentage over 100% doesn't make sense.
        require(newFeePercent <= 1e18, "FEE_TOO_HIGH");

        // Update the fee percentage.
        feePercent = newFeePercent;

        emit FeePercentUpdated(newFeePercent);
    }

    /*///////////////////////////////////////////////////////////////
                   UNDERLYING IS WETH CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether the Vault should treat the underlying token as WETH compatible.
    /// @dev If enabled the Vault will allow trusting strategies that accept Ether.
    bool public underlyingIsWETH = false;

    /// @notice Emitted when whether the Vault should treat the underlying as WETH is updated.
    /// @param newUnderlyingIsWETH Whether the Vault nows treats the underlying as WETH.
    event UnderlyingIsWETHUpdated(bool newUnderlyingIsWETH);

    /// @notice Set whether the Vault treats the underlying as WETH.
    /// @param newUnderlyingIsWETH Whether the Vault should treat the underlying as WETH.
    /// @dev The underlying token must have 18 decimals, to match Ether's decimal scheme.
    function setUnderlyingIsWETH(bool newUnderlyingIsWETH) external requiresAuth {
        // Ensure the underlying token's decimals match ETH.
        require(UNDERLYING.decimals() == 18, "WRONG_DECIMALS");

        // Update whether the Vault treats the underlying as WETH.
        underlyingIsWETH = newUnderlyingIsWETH;

        emit UnderlyingIsWETHUpdated(newUnderlyingIsWETH);
    }

    /*///////////////////////////////////////////////////////////////
                       TARGET FLOAT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The desired percentage of the Vault's holdings to keep as float.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public targetFloatPercent = 0.01e18;

    /// @notice Emitted when the target float percentage is updated.
    /// @param newTargetFloatPercent The updated target float percentage.
    event TargetFloatPercentUpdated(uint256 newTargetFloatPercent);

    /// @notice Set a new target float percentage.
    /// @param newTargetFloatPercent The new target float percentage.
    function setTargetFloatPercent(uint256 newTargetFloatPercent) external requiresAuth {
        // A target float percentage over 100% doesn't make sense.
        require(targetFloatPercent <= 1e18, "TARGET_TOO_HIGH");

        // Update the target float percentage.
        targetFloatPercent = newTargetFloatPercent;

        emit TargetFloatPercentUpdated(newTargetFloatPercent);
    }

    /*///////////////////////////////////////////////////////////////
                        HARVEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    //// @notice Emitted when the harvest window is updated.
    //// @param newHarvestWindow The updated harvest window.
    event HarvestWindowUpdated(uint128 newHarvestWindow);

    /// @notice Emitted when the harvest delay is updated.
    /// @param newHarvestDelay The updated harvest delay.
    event HarvestDelayUpdated(uint64 newHarvestDelay);

    /// @notice Emitted when the harvest delay is scheduled to be updated next harvest.
    /// @param newHarvestDelay The scheduled updated harvest delay.
    event HarvestDelayUpdateScheduled(uint64 newHarvestDelay);

    /// @notice The period in seconds during which multiple harvests can occur
    /// regardless if they are taking place before the harvest delay has elapsed.
    /// @dev Longer harvest delays open up the Vault to profit distribution DOS attacks.
    uint128 public harvestWindow = 5 minutes;

    /// @notice The period in seconds over which locked profit is unlocked.
    /// @dev Cannot be 0 as it opens harvests up to sandwich attacks.
    uint64 public harvestDelay = 6 hours;

    /// @notice The value that will replace harvestDelay next harvest.
    /// @dev In the case that the next delay is 0, no update will be applied.
    uint64 public nextHarvestDelay;

    /// @notice Set a new harvest window.
    /// @param newHarvestWindow The new harvest window.
    function setHarvestWindow(uint128 newHarvestWindow) external requiresAuth {
        // A harvest window longer than the harvest delay doesn't make sense.
        require(newHarvestWindow <= harvestDelay, "WINDOW_TOO_LONG");

        // Update the harvest window.
        harvestWindow = newHarvestWindow;

        emit HarvestWindowUpdated(newHarvestWindow);
    }

    /// @notice Set a new harvest delay delay to be applied next harvest.
    /// @param newHarvestDelay The new harvest delay to set.
    function scheduleHarvestUnlockDelayUpdate(uint64 newHarvestDelay) external requiresAuth {
        // A harvest delay of 0 makes harvests vulnerable to sandwich attacks.
        require(newHarvestDelay != 0, "DELAY_CANNOT_BE_ZERO");

        // A target harvest delay over 1 year doesn't make sense.
        require(newHarvestDelay <= 365 days, "DELAY_TOO_LONG");

        // Set the next harvest delay.
        // The update actually be applied next harvest.
        nextHarvestDelay = newHarvestDelay;

        emit HarvestDelayUpdateScheduled(newHarvestDelay);
    }

    /*///////////////////////////////////////////////////////////////
                          STRATEGY STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The total amount of underlying tokens held in strategies at the time of the last harvest.
    /// @dev Includes maxLockedProfit, must be correctly subtracted to compute available/free holdings.
    uint256 public totalStrategyHoldings;

    /// @dev Packed struct of strategy data.
    /// @param trusted Whether the strategy is trusted.
    /// @param balance The amount of underlying tokens held in the strategy.
    struct StrategyData {
        // Used to determine if the Vault will operate on a strategy.
        bool trusted;
        // Used to determine profit and loss during harvests of the strategy.
        uint248 balance;
    }

    /// @notice Maps strategies to data the Vault holds on them.
    mapping(Strategy => StrategyData) public getStrategyData;

    /*///////////////////////////////////////////////////////////////
                             HARVEST STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice A timestamp representing when the first harvest in the most recent harvest window occurred.
    /// @dev May be equal to lastHarvest if there was/has only been one harvest in the most last/current window.
    uint64 public lastHarvestWindowStart;

    /// @notice A timestamp representing when the most recent harvest occurred.
    uint64 public lastHarvest;

    /// @notice The amount of locked profit at the end of the last harvest.
    uint128 public maxLockedProfit;

    /*///////////////////////////////////////////////////////////////
                      WITHDRAWAL QUEUE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice An ordered array of strategies representing the withdrawal queue.
    /// @dev The queue is processed in descending order, meaning the last index will be withdrawn from first.
    Strategy[] public withdrawalQueue;

    /// @notice Gets the full withdrawal queue.
    /// @return An ordered array of strategies representing the withdrawal queue.
    /// @dev This is provided because Solidity converts public arrays into index getters,
    /// but we need a way to allow external contracts and users to access the whole array.
    function getWithdrawalQueue() external view returns (Strategy[] memory) {
        return withdrawalQueue;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful deposit.
    /// @param user The address that deposited into the Vault.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event Deposit(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted after a successful withdrawal.
    /// @param user The address that withdrew from the Vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event Withdraw(address indexed user, uint256 underlyingAmount);

    /// @notice Deposit a specific amount of underlying tokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        // We don't allow depositing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Determine the equivalent amount of rvTokens and mint them.
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit Deposit(msg.sender, underlyingAmount);

        // Transfer in underlying tokens from the user.
        // This will revert if the user does not have the amount specified.
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);
    }

    /// @notice Withdraw a specific amount of underlying tokens.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdraw(uint256 underlyingAmount) external {
        // We don't allow withdrawing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Determine the equivalent amount of rvTokens and burn them.
        // This will revert if the user does not have enough rvTokens.
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit Withdraw(msg.sender, underlyingAmount);

        // Withdraw from strategies (if needed) and transfer.
        transferUnderlyingTo(msg.sender, underlyingAmount);
    }

    /// @notice Redeem a specific amount of rvTokens for underlying tokens.
    /// @param rvTokenAmount The amount of rvTokens to redeem for underlying tokens.
    function redeem(uint256 rvTokenAmount) external {
        // We don't allow redeeming 0 to prevent emitting a useless event.
        require(rvTokenAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Determine the equivalent amount of underlying tokens.
        uint256 underlyingAmount = rvTokenAmount.fmul(exchangeRate(), BASE_UNIT);

        // Burn the provided amount of rvTokens.
        // This will revert if the user does not have enough rvTokens.
        _burn(msg.sender, rvTokenAmount);

        emit Withdraw(msg.sender, underlyingAmount);

        // Withdraw from strategies (if needed) and transfer.
        transferUnderlyingTo(msg.sender, underlyingAmount);
    }

    /// @dev Transfers a specific amount of underlying tokens held in strategies and/or float to a recipient.
    /// @dev Only withdraws from strategies if needed and maintains the target float percentage if possible.
    /// @param recipient The user to transfer the underlying tokens to.
    /// @param underlyingAmount The amount of underlying tokens to transfer.
    function transferUnderlyingTo(address recipient, uint256 underlyingAmount) internal {
        // Get the Vault's floating balance.
        uint256 float = totalFloat();

        // If the amount is greater than the float, withdraw from strategies.
        if (underlyingAmount > float) {
            // Compute the bare minimum we need for this withdrawal.
            uint256 floatDelta = underlyingAmount - float;

            // Compute the amount needed to reach our target float percentage.
            uint256 targetFloatDelta = (totalHoldings() - underlyingAmount).fmul(targetFloatPercent, 1e18);

            // Pull the desired amount from the withdrawal queue.
            pullFromWithdrawalQueue((floatDelta + targetFloatDelta).safeCastTo224());
        }

        // Transfer the provided amount of underlying tokens.
        UNDERLYING.safeTransfer(recipient, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's Vault balance in underlying tokens.
    /// @param user The user to get the underlying balance of.
    /// @return The user's Vault balance in underlying tokens.
    function balanceOfUnderlying(address user) external view returns (uint256) {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /// @notice Returns the amount of underlying tokens an rvToken can be redeemed for.
    /// @return The amount of underlying tokens an rvToken can be redeemed for.
    function exchangeRate() public view returns (uint256) {
        // Get the total supply of rvTokens.
        uint256 rvTokenSupply = totalSupply;

        // If there are no rvTokens in circulation, return an exchange rate of 1:1.
        if (rvTokenSupply == 0) return BASE_UNIT;

        // Calculate the exchange rate by diving the total holdings by the rvToken supply.
        return totalHoldings().fdiv(rvTokenSupply, BASE_UNIT);
    }

    /// @notice Calculate the total amount of underlying tokens the Vault holds.
    /// @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    function totalHoldings() public view returns (uint256 totalUnderlyingHeld) {
        unchecked {
            // Cannot underflow as locked profit can't exceed total strategy holdings.
            totalUnderlyingHeld = totalStrategyHoldings - lockedProfit();
        }

        // Include our floating balance in the total.
        totalUnderlyingHeld += totalFloat();
    }

    /// @notice Calculate the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // Get the last harvest and harvest delay.
        uint256 previousHarvest = lastHarvest;
        uint256 harvestInterval = harvestDelay;

        unchecked {
            // If the harvest delay has passed, there is no locked profit.
            // Cannot overflow on human timescales since harvestInterval is capped.
            if (block.timestamp >= previousHarvest + harvestInterval) return 0;

            // Get the maximum amount we could return.
            uint256 maximumLockedProfit = maxLockedProfit;

            // Compute how much profit remains locked based on the last harvest and harvest delay.
            // It's impossible for the previous harvest to be in the future, so this will never underflow.
            return maximumLockedProfit - (maximumLockedProfit * (block.timestamp - previousHarvest)) / harvestInterval;
        }
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                             HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful harvest.
    /// @param strategy The strategy that was harvested.
    /// @param profitAccrued The amount of profit accrued by the harvest.
    /// @param feesAccrued The amount of fees accrued during the harvest.
    /// @dev If profitAccrued is 0 that could mean the strategy registered a loss.
    event Harvest(Strategy indexed strategy, uint256 profitAccrued, uint256 feesAccrued);

    /// @notice Harvest a trusted strategy.
    /// @param strategy The trusted strategy to harvest.
    /// @dev Heavily optimized at the cost of some readability, as this function must
    /// be called frequently by altruistic actors for the Vault to function as intended.
    function harvest(Strategy strategy) external {
        // If an untrusted strategy could be harvested a malicious user could use
        // a fake strategy that over-reports holdings to manipulate the exchange rate.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // If this is the first harvest after the last window:
        if (block.timestamp >= lastHarvest + harvestDelay) {
            // Set the harvest window's start timestamp.
            lastHarvestWindowStart = uint64(block.timestamp);
        } else {
            // We know this harvest is not the first in the window so we need to ensure it's within it.
            require(block.timestamp <= lastHarvestWindowStart + harvestWindow, "BAD_HARVEST_TIME");
        }

        // Get the Vault's current total strategy holdings.
        uint256 strategyHoldings = totalStrategyHoldings;

        // Get the strategy's previous and current balance.
        uint256 balanceLastHarvest = getStrategyData[strategy].balance;
        uint256 balanceThisHarvest = strategy.balanceOfUnderlying(address(this));

        // Compute the profit since last harvest. Will be 0 if it it had a net loss.
        uint256 profitAccrued = balanceThisHarvest > balanceLastHarvest
            ? balanceThisHarvest - balanceLastHarvest // Profits since last harvest.
            : 0; // If the strategy registered a net loss we don't have any new profit.

        // Compute fees as the fee percent multiplied by the profit.
        uint256 feesAccrued = profitAccrued.fmul(feePercent, 1e18);

        // If we accrued any fees, mint an equivalent amount of fvTokens.
        // Authorized users can claim the newly minted fvTokens via claimFees.
        if (feesAccrued != 0)
            _mint(
                address(this),
                feesAccrued.fdiv(
                    // Optimized equivalent to exchangeRate. We don't subtract
                    // locked profit because it will always be 0 during a harvest.
                    (strategyHoldings + totalFloat()).fdiv(totalSupply, BASE_UNIT),
                    BASE_UNIT
                )
            );

        // Increase/decrease totalStrategyHoldings based on the profit/loss registered.
        // We cannot wrap the subtraction in parenthesis as it would underflow if the strategy had a loss.
        totalStrategyHoldings = strategyHoldings + balanceThisHarvest - balanceLastHarvest;

        // Update our stored balance for the strategy.
        getStrategyData[strategy].balance = balanceThisHarvest.safeCastTo224();

        // Update the max amount of locked profit.
        maxLockedProfit = uint128(profitAccrued - feesAccrued);

        // Update the last harvest timestamp.
        lastHarvest = uint64(block.timestamp);

        // Get the next harvest delay.
        uint64 newHarvestDelay = nextHarvestDelay;

        // If the next harvest delay is not 0:
        if (newHarvestDelay != 0) {
            // Update the harvest delay.
            harvestDelay = newHarvestDelay;

            // Reset the next harvest delay.
            nextHarvestDelay = 0;

            emit HarvestDelayUpdated(newHarvestDelay);
        }

        emit Harvest(strategy, profitAccrued, feesAccrued);
    }

    /*///////////////////////////////////////////////////////////////
                    STRATEGY DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after the Vault deposits into a strategy contract.
    /// @param strategy The strategy that was deposited into.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event StrategyDeposit(Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after the Vault withdraws funds from a strategy contract.
    /// @param strategy The strategy that was withdrawn from.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event StrategyWithdrawal(Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Deposit a specific amount of float into a trusted strategy.
    /// @param strategy The trusted strategy to deposit into.
    /// @param underlyingAmount The amount of underlying tokens in float to deposit.
    function depositIntoStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be deposited into.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // We don't allow depositing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Increase totalStrategyHoldings to account for the deposit.
        totalStrategyHoldings += underlyingAmount;

        unchecked {
            // Without this the next harvest would count the deposit as profit.
            // Cannot overflow as the balance of one strategy can't exceed the sum of all.
            getStrategyData[strategy].balance += underlyingAmount.safeCastTo224();
        }

        emit StrategyDeposit(strategy, underlyingAmount);

        // We need to deposit differently if the strategy takes ETH.
        if (strategy.isCEther()) {
            // Unwrap the right amount of WETH.
            WETH(payable(address(UNDERLYING))).withdraw(underlyingAmount);

            // Deposit into the strategy and assume it will revert on error.
            ETHStrategy(address(strategy)).mint{value: underlyingAmount}();
        } else {
            // Approve underlyingAmount to the strategy so we can deposit.
            UNDERLYING.safeApprove(address(strategy), underlyingAmount);

            // Deposit into the strategy and revert if it returns an error code.
            require(ERC20Strategy(address(strategy)).mint(underlyingAmount) == 0, "MINT_FAILED");
        }
    }

    /// @notice Withdraw a specific amount of underlying tokens from a strategy.
    /// @param strategy The strategy to withdraw from.
    /// @param underlyingAmount  The amount of underlying tokens to withdraw.
    /// @dev Withdrawing from a strategy will not remove it from the withdrawal queue.
    function withdrawFromStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be withdrawn from.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // We don't allow withdrawing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Without this the next harvest would count the withdrawal as a loss.
        getStrategyData[strategy].balance -= underlyingAmount.safeCastTo224();

        unchecked {
            // Decrease totalStrategyHoldings to account for the withdrawal.
            // Cannot underflow as the balance of one strategy will never exceed the sum of all.
            totalStrategyHoldings -= underlyingAmount;
        }

        emit StrategyWithdrawal(strategy, underlyingAmount);

        // Withdraw from the strategy and revert if returns an error code.
        require(strategy.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");

        // Wrap the withdrawn Ether into WETH if necessary.
        if (strategy.isCEther()) WETH(payable(address(UNDERLYING))).deposit{value: underlyingAmount}();
    }

    /*///////////////////////////////////////////////////////////////
                        STRATEGY TRUST LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a strategy is set to trusted.
    /// @param strategy The strategy that became trusted.
    event StrategyTrusted(Strategy indexed strategy);

    /// @notice Emitted when a strategy is set to untrusted.
    /// @param strategy The strategy that became untrusted.
    event StrategyDistrusted(Strategy indexed strategy);

    /// @notice Store a strategy as trusted, enabling it to be harvested.
    /// @param strategy The strategy to make trusted.
    function trustStrategy(Strategy strategy) external requiresAuth {
        // Ensure the strategy accepts the correct underlying token.
        // If the strategy accepts ETH the Vault should accept WETH, we'll handle wrapping when necessary.
        require(
            strategy.isCEther() ? underlyingIsWETH : ERC20Strategy(address(strategy)).underlying() == UNDERLYING,
            "WRONG_UNDERLYING"
        );

        // Store the strategy as trusted.
        getStrategyData[strategy].trusted = true;

        emit StrategyTrusted(strategy);
    }

    /// @notice Store a strategy as untrusted, disabling it from being harvested.
    /// @param strategy The strategy to make untrusted.
    function distrustStrategy(Strategy strategy) external requiresAuth {
        // Store the strategy as untrusted.
        getStrategyData[strategy].trusted = false;

        emit StrategyDistrusted(strategy);
    }

    /*///////////////////////////////////////////////////////////////
                        WITHDRAWAL QUEUE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a strategy is pushed to the withdrawal queue.
    /// @param pushedStrategy The strategy pushed to the withdrawal queue.
    event WithdrawalQueuePushed(Strategy pushedStrategy);

    /// @notice Emitted when a strategy is popped from the withdrawal queue.
    /// @param poppedStrategy The strategy popped from the withdrawal queue.
    event WithdrawalQueuePopped(Strategy poppedStrategy);

    /// @notice Emitted when the withdrawal queue is updated.
    /// @param replacedWithdrawalQueue The new withdrawal queue.
    event WithdrawalQueueSet(Strategy[] replacedWithdrawalQueue);

    /// @notice Emitted when an index in the withdrawal queue is replaced.
    /// @param index The index of the replaced strategy in the withdrawal queue.
    /// @param replacedStrategy The strategy in the withdrawal queue that was replaced.
    /// @param replacementStrategy The strategy that overrode the replaced strategy at the index.
    event WithdrawalQueueIndexReplaced(uint256 index, Strategy replacedStrategy, Strategy replacementStrategy);

    /// @notice Emitted when an index in the withdrawal queue is replaced with the tip.
    /// @param index The index of the replaced strategy in the withdrawal queue.
    /// @param replacedStrategy The strategy in the withdrawal queue replaced by the tip.
    /// @param previousTipStrategy The previous tip of the queue that replaced the strategy.
    event WithdrawalQueueIndexReplacedWithTip(uint256 index, Strategy replacedStrategy, Strategy previousTipStrategy);

    /// @notice Emitted when the strategies at two indexes are swapped.
    /// @param index1 One index involved in the swap
    /// @param index2 The other index involved in the swap.
    /// @param newStrategy1 The strategy (previously at index2) that replaced index1.
    /// @param newStrategy2 The strategy (previously at index1) that replaced index2.
    event WithdrawalQueueIndexesSwapped(uint256 index1, uint256 index2, Strategy newStrategy1, Strategy newStrategy2);

    /// @dev Withdraw a specific amount of underlying tokens from strategies in the withdrawal queue.
    /// @param underlyingAmount The amount of underlying tokens to pull into float.
    /// @dev Automatically removes depleted strategies from the withdrawal queue.
    function pullFromWithdrawalQueue(uint256 underlyingAmount) internal {
        // We will update this variable as we pull from strategies.
        uint256 amountLeftToPull = underlyingAmount;

        // Store the starting index which is at the tip of the queue.
        // Will revert due to underflow if there are no strategies in the queue.
        uint256 startingIndex = withdrawalQueue.length - 1;

        // We will use this after the loop to check how many strategies we withdrew from.
        uint256 currentIndex = startingIndex;

        // Iterate in reverse so we pull from the queue in a "last in, first out" manner.
        // Will revert due to underflow if we empty the queue before pulling the desired amount.
        for (; ; currentIndex--) {
            // Get the strategy at the current queue index.
            Strategy strategy = withdrawalQueue[currentIndex];

            // Get the balance of the strategy before we withdraw from it.
            uint256 strategyBalance = getStrategyData[strategy].balance;

            // We want to pull as much as we can from the strategy, but no more than we need.
            uint256 amountToPull = FixedPointMathLib.min(amountLeftToPull, strategyBalance);

            unchecked {
                // Compute the balance of the strategy that will remain after we withdraw.
                // Cannot overflow as we cap the amount to pull at the strategy's balance.
                uint256 strategyBalanceAfterWithdrawal = strategyBalance - amountToPull;

                // Without this the next harvest would count the withdrawal as a loss.
                getStrategyData[strategy].balance = strategyBalanceAfterWithdrawal.safeCastTo224();

                // Adjust our goal based on how much we can pull from the strategy.
                // Cannot overflow as we cap the amount to pull at the amount left to pull.
                amountLeftToPull -= amountToPull;

                // Withdraw from the strategy and revert if returns an error code.
                require(strategy.redeemUnderlying(amountToPull) == 0, "REDEEM_FAILED");

                emit StrategyWithdrawal(strategy, amountToPull);

                // If we depleted the strategy, pop it from the queue.
                if (strategyBalanceAfterWithdrawal == 0) {
                    withdrawalQueue.pop();

                    emit WithdrawalQueuePopped(strategy);
                }
            }

            // If we've pulled all we need, exit the loop.
            if (amountLeftToPull == 0) break;
        }

        unchecked {
            // Account for the withdrawals done in the loop above.
            // Cannot overflow as the balances of some strategies cannot exceed the sum of all.
            totalStrategyHoldings -= underlyingAmount;
        }

        // Cache the Vault's balance of Ether.
        uint256 ethBalance = address(this).balance;

        // If the Vault's underlying token is WETH compatible and we have some ETH, wrap it into WETH.
        if (ethBalance != 0 && underlyingIsWETH) WETH(payable(address(UNDERLYING))).deposit{value: ethBalance}();
    }

    /// @notice Push a single strategy to front of the withdrawal queue.
    /// @param strategy The strategy to be inserted at the front of the withdrawal queue.
    function pushToWithdrawalQueue(Strategy strategy) external requiresAuth {
        withdrawalQueue.push(strategy);

        emit WithdrawalQueuePushed(strategy);
    }

    /// @notice Remove the strategy at the tip of the withdrawal queue.
    /// @dev Be careful, another authorized user could push a different strategy
    /// than expected to the queue while a popFromWithdrawalQueue transaction is pending.
    function popFromWithdrawalQueue() external requiresAuth {
        // Get the (soon to be) popped strategy.
        Strategy poppedStrategy = withdrawalQueue[withdrawalQueue.length - 1];

        withdrawalQueue.pop();

        emit WithdrawalQueuePopped(poppedStrategy);
    }

    /// @notice Set the withdrawal queue.
    /// @param newQueue The new withdrawal queue.
    function setWithdrawalQueue(Strategy[] calldata newQueue) external requiresAuth {
        withdrawalQueue = newQueue;

        emit WithdrawalQueueSet(newQueue);
    }

    /// @notice Replace an index in the withdrawal queue with another strategy.
    /// @param index The index in the queue to replace.
    /// @param replacementStrategy The strategy to override the index with.
    function replaceWithdrawalQueueIndex(uint256 index, Strategy replacementStrategy) external {
        // Get the (soon to be) replaced strategy.
        Strategy replacedStrategy = withdrawalQueue[index];

        withdrawalQueue[index] = replacementStrategy;

        emit WithdrawalQueueIndexReplaced(index, replacedStrategy, replacementStrategy);
    }

    /// @notice Move the strategy at the tip of the queue to the specified index and pop the tip off the queue.
    /// @param index The index of the strategy in the withdrawal queue to replace with the tip.
    function replaceWithdrawalQueueIndexWithTip(uint256 index) external requiresAuth {
        // Get the (soon to be) previous tip and strategy we will replace at the index.
        Strategy previousTipStrategy = withdrawalQueue[withdrawalQueue.length - 1];
        Strategy replacedStrategy = withdrawalQueue[index];

        // Replace the index specified with the tip of the queue.
        withdrawalQueue[index] = previousTipStrategy;

        // Remove the now duplicated tip from the array.
        withdrawalQueue.pop();

        emit WithdrawalQueueIndexReplacedWithTip(index, replacedStrategy, previousTipStrategy);
    }

    /// @notice Swap two indexes in the withdrawal queue.
    /// @param index1 One index involved in the swap
    /// @param index2 The other index involved in the swap.
    function swapWithdrawalQueueIndexes(uint256 index1, uint256 index2) external {
        // Get the (soon to be) new strategies at each index.
        Strategy newStrategy2 = withdrawalQueue[index1];
        Strategy newStrategy1 = withdrawalQueue[index2];

        withdrawalQueue[index1] = newStrategy1;
        withdrawalQueue[index2] = newStrategy2;

        emit WithdrawalQueueIndexesSwapped(index1, index2, newStrategy1, newStrategy2);
    }

    /*///////////////////////////////////////////////////////////////
                             FEE CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after fees are claimed.
    /// @param fvTokenAmount The amount of fvTokens that were claimed.
    event FeesClaimed(uint256 fvTokenAmount);

    /// @notice Claims fees accrued from harvests.
    /// @param fvTokenAmount The amount of fvTokens to claim.
    /// @dev Accrued fees are measured as fvTokens held by the Vault.
    function claimFees(uint256 fvTokenAmount) external requiresAuth {
        // Transfer the provided amount of fvTokens to the caller.
        ERC20(this).safeTransfer(msg.sender, fvTokenAmount);

        emit FeesClaimed(fvTokenAmount);
    }

    /*///////////////////////////////////////////////////////////////
                         SEIZE STRATEGY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a strategy is seized.
    /// @param strategy The strategy that was seized.
    event StrategySeized(Strategy indexed strategy);

    /// @notice Seizes a strategy.
    /// @param strategy The strategy to seize.
    /// @dev Intended for use in emergencies or other extraneous situations where the
    /// strategy requires interaction outside of the Vault's standard operating procedures.
    function seizeStrategy(Strategy strategy) external requiresAuth {
        // A strategy must be trusted before it can be seized.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // Get balance the strategy last reported holding.
        uint256 strategyBalance = getStrategyData[strategy].balance;

        // If the strategy's balance exceeds the Vault's total
        // holdings, instantly unlock any remaining locked profit.
        // Only necessary if the strategy has a lot of unlocked profit.
        if (totalHoldings() >= strategyBalance) maxLockedProfit = 0;

        // Decrease the total by the strategy's balance.
        totalStrategyHoldings - strategyBalance;

        // Set the strategy's balance to 0.
        getStrategyData[strategy].balance = 0;

        emit StrategySeized(strategy);

        // Transfer all of the strategy's tokens to the caller.
        ERC20(strategy).safeTransfer(msg.sender, strategy.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}

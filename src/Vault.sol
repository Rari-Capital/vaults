// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Auth} from "solmate/auth/Auth.sol";
import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {WETH} from "./interfaces/WETH.sol";
import {Strategy, ERC20Strategy, ETHStrategy} from "./interfaces/Strategy.sol";

import {VaultFactory} from "./VaultFactory.sol";

/// @title Rari Vault (rvToken)
/// @author Transmissions11 + JetJadeja
/// @notice Minimalist yield aggregator designed to support any ERC20 token.
contract Vault is ERC20, Auth {
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point multiplication and division.
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
                          FEE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The percentage of profit recognized each harvest to reserve as fees.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public feePercent = 0.1e18;

    /// @notice Emitted when the fee percent is updated.
    /// @param newFeePercent The updated fee percent.
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
                       TARGET FLOAT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The desired percentage of the Vault's holdings to keep as float.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public targetFloatPercent = 0.01e18;

    /// @notice Emitted when the target float percent is updated.
    /// @param newTargetFloatPercent The updated target float percent delay.
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
                          STRATEGY STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The total amount of underlying tokens held in strategies at the time of the last harvest.
    /// @dev Includes maxLockedProfit, must be correctly subtracted to compute available/free holdings.
    uint256 public totalStrategyHoldings;

    /// @notice Maps strategies to the amount of underlying tokens they held last harvest.
    mapping(Strategy => uint256) public balanceOfStrategy;

    /// @notice Maps strategies to a boolean representing if the strategy is trusted.
    /// @dev A strategy must be trusted for harvest to be called with it.
    mapping(Strategy => bool) public isStrategyTrusted;

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

        // We don't allow trusting again to prevent emitting a useless event.
        require(!isStrategyTrusted[strategy], "ALREADY_TRUSTED");

        // Store the strategy as trusted.
        isStrategyTrusted[strategy] = true;

        emit StrategyTrusted(strategy);
    }

    /// @notice Store a strategy as untrusted, disabling it from being harvested.
    /// @param strategy The strategy to make untrusted.
    function distrustStrategy(Strategy strategy) external requiresAuth {
        // We don't allow untrusting again to prevent emitting a useless event.
        require(isStrategyTrusted[strategy], "ALREADY_UNTRUSTED");

        // Store the strategy as untrusted.
        isStrategyTrusted[strategy] = false;

        emit StrategyDistrusted(strategy);
    }

    /*///////////////////////////////////////////////////////////////
                             HARVEST STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice A timestamp representing when the last harvest occurred.
    uint256 public lastHarvest;

    /// @notice The amount of locked profit at the end of the last harvest.
    uint256 public maxLockedProfit;

    /// @notice The approximate period in seconds over which locked profits are unlocked.
    /// @dev Defaults to 6 hours. Cannot be 0 as it opens harvests to sandwich attacks.
    uint256 public profitUnlockDelay = 6 hours;

    /// @notice Emitted when the profit unlock delay is updated.
    /// @param newProfitUnlockDelay The updated profit unlock delay.
    event ProfitUnlockDelayUpdated(uint256 newProfitUnlockDelay);

    /// @notice Set a new profit unlock delay delay.
    /// @param newProfitUnlockDelay The new profit unlock delay.
    function setProfitUnlockDelay(uint256 newProfitUnlockDelay) external requiresAuth {
        // An unlock delay of 0 makes harvests vulnerable to sandwich attacks.
        require(profitUnlockDelay != 0, "DELAY_CANNOT_BE_ZERO");

        // Update the profit unlock delay.
        profitUnlockDelay = newProfitUnlockDelay;

        emit ProfitUnlockDelayUpdated(newProfitUnlockDelay);
    }

    /*///////////////////////////////////////////////////////////////
                      WITHDRAWAL QUEUE MANAGEMENT
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
        // TODO: OPTIMIZE AAAA

        // Get the (soon to be) new strategies at each index.
        Strategy newStrategy2 = withdrawalQueue[index1];
        Strategy newStrategy1 = withdrawalQueue[index2];

        withdrawalQueue[index1] = newStrategy1;
        withdrawalQueue[index2] = newStrategy2;

        emit WithdrawalQueueIndexesSwapped(index1, index2, newStrategy1, newStrategy2);
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

        // If the amount is greater than the float, withdraw from strategies.
        // TODO: Optimize double calls to totalFloat()? One is also done in totalHoldings.
        if (underlyingAmount > totalFloat()) {
            pullFromWithdrawalQueue(
                // The bare minimum we need for this withdrawal.
                (underlyingAmount - totalFloat()) +
                    // The amount needed to reach our target float percentage.
                    (totalHoldings() - underlyingAmount).fmul(targetFloatPercent, 1e18)
            );
        }

        // Transfer the provided amount of underlying tokens.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);
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

        // If the amount is greater than the float, withdraw from strategies.
        // TODO: Optimize double calls to totalFloat()? One is also done in totalHoldings.
        if (underlyingAmount > totalFloat()) {
            pullFromWithdrawalQueue(
                // The bare minimum we need for this withdrawal.
                (underlyingAmount - totalFloat()) +
                    // The amount needed to reach our target float percentage.
                    (totalHoldings() - underlyingAmount).fmul(targetFloatPercent, 1e18)
            );
        }

        // Transfer the determined amount of underlying tokens.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's Vault balance in underlying tokens.
    /// @return The user's Vault balance in underlying tokens.
    function balanceOfUnderlying(address account) external view returns (uint256) {
        return balanceOf[account].fmul(exchangeRate(), BASE_UNIT);
    }

    /// @notice Returns the amount of underlying tokens an rvToken can be redeemed for.
    /// @return The amount of underlying tokens an rvToken can be redeemed for.
    function exchangeRate() public view returns (uint256) {
        // If there are no rvTokens in circulation, return an exchange rate of 1:1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        // Calculate the exchange rate by diving the total holdings by the rvToken supply.
        return totalHoldings().fdiv(totalSupply, BASE_UNIT);
    }

    /// @notice Calculate the total amount of tokens the Vault currently holds for depositors.
    /// @return The total amount of tokens the Vault currently holds for depositors.
    function totalHoldings() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract locked profit from totalStrategyHoldings because maxLockedProfit is baked into it.
        return totalFloat() + totalStrategyHoldings - lockedProfit();
    }

    /// @notice Calculate the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // TODO: Cache SLOADs?
        return
            block.timestamp >= lastHarvest + profitUnlockDelay
                ? 0 // If profit unlock delay has passed, there is no locked profit.
                : maxLockedProfit - (maxLockedProfit * (block.timestamp - lastHarvest)) / profitUnlockDelay;
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
    /// @param lockedProfit The amount of locked profit after the harvest.
    event Harvest(Strategy indexed strategy, uint256 lockedProfit);

    /// @notice Harvest a trusted strategy.
    /// @param strategy The trusted strategy to harvest.
    function harvest(Strategy strategy) external {
        // If an untrusted strategy could be harvested a malicious user could
        // construct a fake strategy that over-reports holdings to manipulate share price.
        require(isStrategyTrusted[strategy], "UNTRUSTED_STRATEGY");

        uint256 balanceLastHarvest = balanceOfStrategy[strategy];
        uint256 balanceThisHarvest = strategy.balanceOfUnderlying(address(this));

        // Update our stored balance for the strategy.
        balanceOfStrategy[strategy] = balanceThisHarvest;

        // Increase/decrease totalStrategyHoldings based on the profit/loss registered.
        // We cannot wrap the subtraction in parenthesis as it would underflow if the strategy had a loss.
        totalStrategyHoldings = totalStrategyHoldings + balanceThisHarvest - balanceLastHarvest;

        // Update maxLockedProfit to include any new profit.
        maxLockedProfit =
            lockedProfit() +
            (
                balanceThisHarvest > balanceLastHarvest
                    ? balanceThisHarvest - balanceLastHarvest // Profits since last harvest.
                    : 0 // If the strategy registered a net loss we don't have any new profit to lock.
            );

        // Set lastHarvest to the current timestamp.
        lastHarvest = block.timestamp;

        // TODO: Cache SLOAD here?
        emit Harvest(strategy, maxLockedProfit);
    }

    /*///////////////////////////////////////////////////////////////
                            REBALANCE LOGIC
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
        require(isStrategyTrusted[strategy], "UNTRUSTED_STRATEGY");

        // We don't allow exiting 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Without this the next harvest would count the deposit as profit.
        balanceOfStrategy[strategy] += underlyingAmount;

        // Increase totalStrategyHoldings to account for the deposit.
        totalStrategyHoldings += underlyingAmount;

        emit StrategyDeposit(strategy, underlyingAmount);

        // We need to deposit differently if the strategy takes ETH.
        if (strategy.isCEther()) {
            // Unwrap the right amount of WETH.
            WETH(address(UNDERLYING)).withdraw(underlyingAmount);

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
        // We don't allow exiting 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Without this the next harvest would count the withdrawal as a loss.
        balanceOfStrategy[strategy] -= underlyingAmount;

        // Decrease totalStrategyHoldings to account for the withdrawal.
        totalStrategyHoldings -= underlyingAmount;

        emit StrategyWithdrawal(strategy, underlyingAmount);

        // Withdraw from the strategy and revert if returns an error code.
        require(strategy.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");

        // Wrap the withdrawn Ether into WETH if necessary.
        if (strategy.isCEther()) WETH(address(UNDERLYING)).deposit{value: underlyingAmount}();
    }

    /*///////////////////////////////////////////////////////////////
                       STRATEGY WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraw a specific amount of underlying tokens from strategies in the withdrawal queue.
    /// @param underlyingAmount The amount of underlying tokens to pull into float.
    /// @dev Automatically removes depleted strategies from the withdrawal queue.
    function pullFromWithdrawalQueue(uint256 underlyingAmount) internal {
        // TODO: Cache variables to optimize SLOADs.

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

            // We want to pull as much as we can from the strategy, but no more than we need.
            uint256 amountToPull = FixedPointMathLib.min(amountLeftToPull, balanceOfStrategy[strategy]);

            // Without this the next harvest would count the withdrawal as a loss.
            balanceOfStrategy[strategy] -= amountToPull;

            // Adjust our goal based on how much we can pull from the strategy.
            amountLeftToPull -= amountToPull;

            // Withdraw from the strategy and revert if returns an error code.
            require(strategy.redeemUnderlying(amountToPull) == 0, "REDEEM_FAILED");

            emit StrategyWithdrawal(strategy, amountToPull);

            // If we depleted the strategy, pop it from the queue.
            if (balanceOfStrategy[strategy] == 0) {
                withdrawalQueue.pop();

                emit WithdrawalQueuePopped(strategy);
            }

            // If we've pulled all we need, exit the loop.
            if (amountLeftToPull == 0) break;
        }

        // Account for the withdrawals.
        totalStrategyHoldings -= underlyingAmount;

        // Cache the Vault's balance of Ether.
        uint256 ethBalance = address(this).balance;

        // If we now have any ETH, meaning we withdrew from some ETH strategies, wrap it into WETH.
        if (ethBalance != 0 && underlyingIsWETH) WETH(address(UNDERLYING)).deposit{value: ethBalance}();
    }

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}

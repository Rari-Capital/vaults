// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockStrategy} from "./mocks/MockStrategy.sol";

import {Strategy} from "../interfaces/Strategy.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    MockStrategy strategy1;
    MockStrategy strategy2;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new VaultFactory().deployVault(underlying);

        strategy1 = new MockStrategy(underlying);
        strategy2 = new MockStrategy(underlying);
    }

    /*///////////////////////////////////////////////////////////////
                      BASIC DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicDepositWithdraw() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.withdraw(1e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    function testAtomicDepositRedeem() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.redeem(1e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    /*///////////////////////////////////////////////////////////////
                 DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositWithNotEnoughApproval() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(1e18);
    }

    function testFailWithdrawWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(0.5e18);

        vault.withdraw(1e18);
    }

    function testFailRedeemWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(0.5e18);

        vault.redeem(1e18);
    }

    function testFailRedeemWithNoBalance() public {
        vault.redeem(1e18);
    }

    function testFailWithdrawWithNoBalance() public {
        vault.withdraw(1e18);
    }

    function testFailDepositWithNoApproval() public {
        vault.deposit(1e18);
    }

    function testFailRedeemZero() public {
        vault.redeem(0);
    }

    function testFailWithdrawZero() public {
        vault.withdraw(0);
    }

    function testFailDepositZero() public {
        vault.deposit(0);
    }

    /*///////////////////////////////////////////////////////////////
                  BASIC STRATEGY DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicEnterExitSinglePool() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 1e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.withdrawFromStrategy(strategy1, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.withdrawFromStrategy(strategy1, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);
    }

    function testAtomicEnterExitMultiPool() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.trustStrategy(strategy2);

        vault.depositIntoStrategy(strategy2, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.withdrawFromStrategy(strategy1, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.withdrawFromStrategy(strategy2, 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);
    }

    /*///////////////////////////////////////////////////////////////
              STRATEGY DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositIntoStrategyWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(0.5e18);

        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 1e18);
    }

    function testFailWithdrawFromStrategyWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(0.5e18);

        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.withdrawFromStrategy(strategy1, 1e18);
    }

    function testFailDepositIntoStrategyWithNoBalance() public {
        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 1e18);
    }

    function testFailWithdrawFromStrategyWithNoBalance() public {
        vault.withdrawFromStrategy(strategy1, 1e18);
    }

    function testFailDepositIntoStrategyZero() public {
        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, 0);
    }

    function testFailWithdrawFromStrategyZero() public {
        vault.withdrawFromStrategy(strategy1, 0);
    }

    /*///////////////////////////////////////////////////////////////
                         BASIC HARVEST TESTS
    //////////////////////////////////////////////////////////////*/

    function testProfitableHarvest() public {
        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);
        vault.pushToWithdrawalQueue(strategy1);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        underlying.transfer(address(strategy1), 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.harvest(strategy1);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        hevm.warp(block.timestamp + (vault.profitUnlockDelay() / 2));

        assertEq(vault.exchangeRate(), 1.25e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1.25e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1.25e18);

        hevm.warp(block.timestamp + vault.profitUnlockDelay());

        assertEq(vault.exchangeRate(), 1.5e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1.5e18);

        vault.redeem(1e18);
        assertEq(underlying.balanceOf(address(this)), 1.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
    }

    function testUnprofitableHarvest() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);
        vault.pushToWithdrawalQueue(strategy1);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        strategy1.simulateLoss(0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1e18);

        vault.harvest(strategy1);

        assertEq(vault.exchangeRate(), 0.5e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0.5e18);

        vault.redeem(1e18);
        assertEq(underlying.balanceOf(address(this)), 0.5e18);

        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalHoldings(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
    }

    /*///////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailTrustStrategyWithWrongUnderlying() public {
        MockERC20 wrongUnderlying = new MockERC20("Not The Right Token", "TKN2", 18);

        MockStrategy badStrategy = new MockStrategy(wrongUnderlying);

        vault.trustStrategy(badStrategy);
    }

    function testFailWithdrawWithEmptyQueue() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);

        vault.redeem(1e18);
    }

    function testFailWithdrawWithIncompleteQueue() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.pushToWithdrawalQueue(strategy1);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        vault.redeem(1e18);
    }

    function testUpdatingProfitUnlockDelayWhileProfitIsStillLocked() public {
        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);
        vault.pushToWithdrawalQueue(strategy1);

        underlying.transfer(address(strategy1), 0.5e18);
        vault.harvest(strategy1);

        hevm.warp(block.timestamp + (vault.profitUnlockDelay() / 2));
        assertEq(vault.balanceOfUnderlying(address(this)), 1.25e18);

        vault.setProfitUnlockDelay(vault.profitUnlockDelay() * 2);
        assertEq(vault.balanceOfUnderlying(address(this)), 1.125e18);

        hevm.warp(block.timestamp + vault.profitUnlockDelay());
        assertEq(vault.balanceOfUnderlying(address(this)), 1.5e18);

        vault.redeem(1e18);
        assertEq(underlying.balanceOf(address(this)), 1.5e18);
    }

    /*///////////////////////////////////////////////////////////////
                        WITHDRAWAL QUEUE TESTS
    //////////////////////////////////////////////////////////////*/

    function testPushingToWithdrawalQueue() public {
        vault.pushToWithdrawalQueue(Strategy(address(69)));
        vault.pushToWithdrawalQueue(Strategy(address(420)));
        vault.pushToWithdrawalQueue(Strategy(address(1337)));
        vault.pushToWithdrawalQueue(Strategy(address(69420)));

        assertEq(vault.getWithdrawalQueue().length, 4);

        assertEq(address(vault.withdrawalQueue(0)), address(69));
        assertEq(address(vault.withdrawalQueue(1)), address(420));
        assertEq(address(vault.withdrawalQueue(2)), address(1337));
        assertEq(address(vault.withdrawalQueue(3)), address(69420));
    }

    function testPoppingFromWithdrawalQueue() public {
        vault.pushToWithdrawalQueue(Strategy(address(69)));
        vault.pushToWithdrawalQueue(Strategy(address(420)));
        vault.pushToWithdrawalQueue(Strategy(address(1337)));
        vault.pushToWithdrawalQueue(Strategy(address(69420)));

        vault.popFromWithdrawalQueue();

        assertEq(vault.getWithdrawalQueue().length, 3);

        vault.popFromWithdrawalQueue();

        assertEq(vault.getWithdrawalQueue().length, 2);

        vault.popFromWithdrawalQueue();

        assertEq(vault.getWithdrawalQueue().length, 1);

        vault.popFromWithdrawalQueue();

        assertEq(vault.getWithdrawalQueue().length, 0);
    }

    function testReplaceWithdrawalQueueIndex() public {
        Strategy[] memory newQueue = new Strategy[](4);
        newQueue[0] = Strategy(address(1));
        newQueue[1] = Strategy(address(2));
        newQueue[2] = Strategy(address(3));
        newQueue[3] = Strategy(address(4));

        vault.setWithdrawalQueue(newQueue);

        vault.replaceWithdrawalQueueIndex(1, Strategy(address(420)));

        assertEq(vault.getWithdrawalQueue().length, 4);
        assertEq(address(vault.withdrawalQueue(1)), address(420));
    }

    function testReplaceWithdrawalQueueIndexWithTip() public {
        Strategy[] memory newQueue = new Strategy[](4);
        newQueue[0] = Strategy(address(1001));
        newQueue[1] = Strategy(address(1002));
        newQueue[2] = Strategy(address(1003));
        newQueue[3] = Strategy(address(1004));
        vault.setWithdrawalQueue(newQueue);

        vault.replaceWithdrawalQueueIndexWithTip(1);

        assertEq(vault.getWithdrawalQueue().length, 3);
        assertEq(address(vault.withdrawalQueue(2)), address(1003));
        assertEq(address(vault.withdrawalQueue(1)), address(1004));
    }

    function testSwapWithdrawalQueueIndexes() public {
        Strategy[] memory newQueue = new Strategy[](4);
        newQueue[0] = Strategy(address(1001));
        newQueue[1] = Strategy(address(1002));
        newQueue[2] = Strategy(address(1003));
        newQueue[3] = Strategy(address(1004));
        vault.setWithdrawalQueue(newQueue);

        vault.swapWithdrawalQueueIndexes(1, 2);

        assertEq(vault.getWithdrawalQueue().length, 4);
        assertEq(address(vault.withdrawalQueue(1)), address(1003));
        assertEq(address(vault.withdrawalQueue(2)), address(1002));
    }
}

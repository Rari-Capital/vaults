// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {WETH} from "solmate/tokens/WETH.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockETHStrategy} from "./mocks/MockETHStrategy.sol";
import {MockERC20Strategy} from "./mocks/MockERC20Strategy.sol";

import {Strategy} from "../interfaces/Strategy.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

import "forge-std/console.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    MockERC20Strategy strategy1;
    MockERC20Strategy strategy2;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vault = new VaultFactory(address(this), Authority(address(0))).deployVault(underlying);

        vault.setFeePercent(0.1e18);
        vault.setHarvestDelay(6 hours);
        vault.setHarvestWindow(5 minutes);
        vault.setTargetFloatPercent(0.01e18);

        vault.initialize();

        strategy1 = new MockERC20Strategy(underlying);
        strategy2 = new MockERC20Strategy(underlying);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicDepositWithdraw() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18, address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.withdraw(1e18, address(this), address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    function testDepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1e5, 1e27);

        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(amount, address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalFloat(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - amount);

        vault.withdraw(amount, address(this), address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    function testAtomicDepositRedeem() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18, address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.redeem(1e18, address(this), address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    function testDepositRedeem(uint256 amount) public {
        amount = bound(amount, 1e5, 1e27);

        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(amount, address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalFloat(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - amount);

        vault.redeem(amount, address(this), address(this));

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    /*///////////////////////////////////////////////////////////////
                 DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositWithNotEnoughApproval(uint256 amount) public {
        underlying.mint(address(this), amount / 2);
        underlying.approve(address(vault), amount / 2);

        vault.deposit(amount, address(this));
    }

    function testFailWithdrawWithNotEnoughBalance(uint256 amount) public {
        underlying.mint(address(this), amount / 2);
        underlying.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));

        vault.withdraw(amount, address(this), address(this));
    }

    function testFailRedeemWithNotEnoughBalance(uint256 amount) public {
        underlying.mint(address(this), amount / 2);
        underlying.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));

        vault.redeem(amount, address(this), address(this));
    }

    function testFailWithdrawWithNoBalance(uint256 amount) public {
        if (amount == 0) amount = 1;
        vault.withdraw(amount, address(this), address(this));
    }

    function testFailRedeemWithNoBalance(uint256 amount) public {
        vault.redeem(amount, address(this), address(this));
    }

    function testFailDepositWithNoApproval(uint256 amount) public {
        vault.deposit(amount, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                     STRATEGY DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicEnterExitSinglePool(uint256 amount) public {
        amount = bound(amount, 1e12, 1e27);

        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), amount);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);

        vault.withdrawFromStrategy(strategy1, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalFloat(), amount / 2);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertApproxEq(vault.totalStrategyHoldings(), amount / 2, 2);

        vault.withdrawFromStrategy(strategy1, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertApproxEq(vault.totalFloat(), amount, 2); // Approx
        assertEq(vault.totalStrategyHoldings() / 10, 0); // Aprox
    }

    function testAtomicEnterExitMultiPool(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), amount / 2);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertApproxEq(vault.totalFloat(), amount / 2, 2); // Approx

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertApproxEq(vault.totalStrategyHoldings(), amount, 2); // Approx
        assertLt(vault.totalFloat(), 2);

        vault.withdrawFromStrategy(strategy1, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), amount / 2);
        assertEq(vault.totalAssets(), amount);
        assertApproxEq(vault.totalFloat(), amount / 2, 2); // Approx
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);

        vault.withdrawFromStrategy(strategy2, amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalFloat(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
    }

    /*///////////////////////////////////////////////////////////////
              STRATEGY DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositIntoStrategyWithNotEnoughBalance(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        underlying.mint(address(this), amount / 2);
        underlying.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));

        vault.trustStrategy(strategy1);

        vault.depositIntoStrategy(strategy1, amount);
    }

    function testFailWithdrawFromStrategyWithNotEnoughBalance(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        underlying.mint(address(this), amount / 2);
        underlying.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));
        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount / 2);

        vault.withdrawFromStrategy(strategy1, amount);
    }

    function testFailWithdrawFromStrategyWithoutTrust(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);

        vault.deposit(amount, address(this));
        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount);

        vault.distrustStrategy(strategy1);
        vault.withdrawFromStrategy(strategy1, amount);
    }

    function testFailDepositIntoStrategyWithNoBalance(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount);
    }

    function testFailWithdrawFromStrategyWithNoBalance(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);

        vault.trustStrategy(strategy1);
        vault.withdrawFromStrategy(strategy1, 1e18);
    }

    /*///////////////////////////////////////////////////////////////
                             HARVEST TESTS
    //////////////////////////////////////////////////////////////*/

    function testProfitableHarvest(uint256 amount) public {
        amount = bound(amount, 1e5, 1e36);
        uint256 total = (1.5e18 * amount) / 1e18;

        underlying.mint(address(this), total);
        underlying.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, amount);
        vault.pushToWithdrawalStack(strategy1);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), amount);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);

        underlying.transfer(address(strategy1), amount / 2);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), amount);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);
        assertEq(vault.lastHarvest(), 0);
        assertEq(vault.lastHarvestWindowStart(), 0);

        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = strategy1;

        vault.harvest(strategiesToHarvest);
        uint256 startingTimestamp = block.timestamp;

        assertEq(vault.lastHarvest(), startingTimestamp);
        assertEq(vault.lastHarvestWindowStart(), startingTimestamp);
        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertApproxEq(vault.totalStrategyHoldings(), total, 1);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), (1.05e18 * amount) / 1e18);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(vault.totalSupply(), (1.05e18 * amount) / 1e18);
        assertEq(vault.balanceOf(address(vault)), (0.05e18 * amount) / 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), (0.05e18 * amount) / 1e18);

        hevm.warp(block.timestamp + (vault.harvestDelay() / 2));

        assertEq(vault.totalStrategyHoldings(), total);
        assertEq(vault.totalFloat(), 0);
        assertGt(vault.totalAssets(), amount);
        assertLt(vault.totalAssets(), total);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.totalSupply(), (1.05e18 * amount) / 1e18);
        assertEq(vault.balanceOf(address(vault)), (0.05e18 * amount) / 1e18);

        assertGt(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertLt(vault.convertToAssets(vault.balanceOf(address(this))), (1.25e18 * amount) / 1e18);
        assertGt(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertLt(vault.convertToAssets(10**vault.decimals()), 1.25e18);

        hevm.warp(block.timestamp + vault.harvestDelay());

        assertEq(vault.totalStrategyHoldings(), total);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), total);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.totalSupply(), (1.05e18 * amount) / 1e18);
        assertEq(vault.balanceOf(address(vault)), (0.05e18 * amount) / 1e18);

        assertGt(vault.convertToAssets(vault.balanceOf(address(this))), (1.4e18 * amount) / 1e18);
        assertLt(vault.convertToAssets(vault.balanceOf(address(this))), (1.5e18 * amount) / 1e18);
        assertGt(vault.convertToAssets(10**vault.decimals()), 1.4e18);
        assertLt(vault.convertToAssets(10**vault.decimals()), 1.5e18);

        vault.redeem(amount, address(this), address(this));

        assertGt(vault.convertToAssets(10**vault.decimals()), 1.4e18);
        assertEq(vault.totalStrategyHoldings(), vault.totalAssets() - vault.totalFloat());
        assertGt(vault.totalFloat(), 0);
        assertGt(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), (0.05e18 * amount) / 1e18);
        assertEq(vault.balanceOf(address(vault)), (0.05e18 * amount) / 1e18);

        assertGt(vault.totalFloat(), 0);
        assertGt(vault.convertToAssets(10**vault.decimals()), 1.4e18);
        assertLt(vault.convertToAssets(10**vault.decimals()), 1.5e18);
    }

    function testUnprofitableHarvest() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);
        vault.pushToWithdrawalStack(strategy1);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 1e18);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);

        strategy1.simulateLoss(0.5e18);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), 1e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 1e18);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);

        assertEq(vault.lastHarvest(), 0);
        assertEq(vault.lastHarvestWindowStart(), 0);

        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = strategy1;

        vault.harvest(strategiesToHarvest);

        uint256 startingTimestamp = block.timestamp;

        assertEq(vault.lastHarvest(), startingTimestamp);
        assertEq(vault.lastHarvestWindowStart(), startingTimestamp);

        assertEq(vault.convertToAssets(10**vault.decimals()), 0.5e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0.5e18);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);

        vault.redeem(1e18, address(this), address(this));

        assertEq(underlying.balanceOf(address(this)), 0.5e18);

        assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(vault))), 0);
    }

    function testMultipleHarvestsInWindow() public {
        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        underlying.transfer(address(strategy1), 0.25e18);
        underlying.transfer(address(strategy2), 0.25e18);

        assertEq(vault.lastHarvest(), 0);
        assertEq(vault.lastHarvestWindowStart(), 0);

        Strategy[] memory strategiesToHarvest = new Strategy[](2);
        strategiesToHarvest[0] = strategy1;
        strategiesToHarvest[1] = strategy2;

        vault.harvest(strategiesToHarvest);

        uint256 startingTimestamp = block.timestamp;

        assertEq(vault.lastHarvest(), startingTimestamp);
        assertEq(vault.lastHarvestWindowStart(), startingTimestamp);

        hevm.warp(block.timestamp + (vault.harvestWindow() / 2));

        uint256 exchangeRateBeforeHarvest = vault.convertToAssets(10**vault.decimals());

        vault.harvest(strategiesToHarvest);

        assertEq(vault.convertToAssets(10**vault.decimals()), exchangeRateBeforeHarvest);

        assertEq(vault.lastHarvest(), block.timestamp);
        assertEq(vault.lastHarvestWindowStart(), startingTimestamp);
    }

    function testUpdatingHarvestDelay() public {
        assertEq(vault.harvestDelay(), 6 hours);
        assertEq(vault.nextHarvestDelay(), 0);

        vault.setHarvestDelay(12 hours);

        assertEq(vault.harvestDelay(), 6 hours);
        assertEq(vault.nextHarvestDelay(), 12 hours);

        vault.trustStrategy(strategy1);

        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = strategy1;

        vault.harvest(strategiesToHarvest);

        assertEq(vault.harvestDelay(), 12 hours);
        assertEq(vault.nextHarvestDelay(), 0);
    }

    function testClaimFees() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.transfer(address(vault), 1e18);

        assertEq(vault.balanceOf(address(vault)), 1e18);
        assertEq(vault.balanceOf(address(this)), 0);

        vault.claimFees(1e18);

        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(this)), 1e18);
    }

    /*///////////////////////////////////////////////////////////////
                        HARVEST SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailHarvestAfterWindowBeforeDelay() public {
        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        Strategy[] memory strategiesToHarvest = new Strategy[](2);
        strategiesToHarvest[0] = strategy1;
        strategiesToHarvest[1] = strategy2;

        vault.harvest(strategiesToHarvest);

        hevm.warp(block.timestamp + vault.harvestWindow() + 1);

        vault.harvest(strategiesToHarvest);
    }

    function testFailHarvestUntrustedStrategy() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);

        vault.distrustStrategy(strategy1);

        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = strategy1;

        vault.harvest(strategiesToHarvest);
    }

    /*///////////////////////////////////////////////////////////////
                        WITHDRAWAL STACK TESTS
    //////////////////////////////////////////////////////////////*/

    function testPushingToWithdrawalStack() public {
        vault.pushToWithdrawalStack(Strategy(address(69)));
        vault.pushToWithdrawalStack(Strategy(address(420)));
        vault.pushToWithdrawalStack(Strategy(address(1337)));
        vault.pushToWithdrawalStack(Strategy(address(69420)));

        assertEq(vault.getWithdrawalStack().length, 4);

        assertEq(address(vault.withdrawalStack(0)), address(69));
        assertEq(address(vault.withdrawalStack(1)), address(420));
        assertEq(address(vault.withdrawalStack(2)), address(1337));
        assertEq(address(vault.withdrawalStack(3)), address(69420));
    }

    function testPoppingFromWithdrawalStack() public {
        vault.pushToWithdrawalStack(Strategy(address(69)));
        vault.pushToWithdrawalStack(Strategy(address(420)));
        vault.pushToWithdrawalStack(Strategy(address(1337)));
        vault.pushToWithdrawalStack(Strategy(address(69420)));

        vault.popFromWithdrawalStack();
        assertEq(vault.getWithdrawalStack().length, 3);

        vault.popFromWithdrawalStack();
        assertEq(vault.getWithdrawalStack().length, 2);

        vault.popFromWithdrawalStack();
        assertEq(vault.getWithdrawalStack().length, 1);

        vault.popFromWithdrawalStack();
        assertEq(vault.getWithdrawalStack().length, 0);
    }

    function testReplaceWithdrawalStackIndex() public {
        Strategy[] memory newStack = new Strategy[](4);
        newStack[0] = Strategy(address(1));
        newStack[1] = Strategy(address(2));
        newStack[2] = Strategy(address(3));
        newStack[3] = Strategy(address(4));

        vault.setWithdrawalStack(newStack);

        vault.replaceWithdrawalStackIndex(1, Strategy(address(420)));

        assertEq(vault.getWithdrawalStack().length, 4);
        assertEq(address(vault.withdrawalStack(1)), address(420));
    }

    function testReplaceWithdrawalStackIndexWithTip() public {
        Strategy[] memory newStack = new Strategy[](4);
        newStack[0] = Strategy(address(1001));
        newStack[1] = Strategy(address(1002));
        newStack[2] = Strategy(address(1003));
        newStack[3] = Strategy(address(1004));

        vault.setWithdrawalStack(newStack);

        vault.replaceWithdrawalStackIndexWithTip(1);

        assertEq(vault.getWithdrawalStack().length, 3);
        assertEq(address(vault.withdrawalStack(2)), address(1003));
        assertEq(address(vault.withdrawalStack(1)), address(1004));
    }

    function testSwapWithdrawalStackIndexes() public {
        Strategy[] memory newStack = new Strategy[](4);
        newStack[0] = Strategy(address(1001));
        newStack[1] = Strategy(address(1002));
        newStack[2] = Strategy(address(1003));
        newStack[3] = Strategy(address(1004));

        vault.setWithdrawalStack(newStack);

        vault.swapWithdrawalStackIndexes(1, 2);

        assertEq(vault.getWithdrawalStack().length, 4);
        assertEq(address(vault.withdrawalStack(1)), address(1003));
        assertEq(address(vault.withdrawalStack(2)), address(1002));
    }

    function testFailPushStackFull() public {
        Strategy[] memory fullStack = new Strategy[](32);

        vault.setWithdrawalStack(fullStack);

        vault.pushToWithdrawalStack(Strategy(address(69)));
    }

    function testFailSetStackTooBig() public {
        Strategy[] memory tooBigStack = new Strategy[](33);

        vault.setWithdrawalStack(tooBigStack);
    }

    function testFailPopStackEmpty() public {
        vault.popFromWithdrawalStack();
    }

    /*///////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdrawingWithDuplicateStrategiesInStack() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        vault.pushToWithdrawalStack(strategy1);
        vault.pushToWithdrawalStack(strategy1);
        vault.pushToWithdrawalStack(strategy2);
        vault.pushToWithdrawalStack(strategy1);
        vault.pushToWithdrawalStack(strategy1);

        assertEq(vault.getWithdrawalStack().length, 5);

        vault.redeem(1e18, address(this), address(this));

        assertEq(vault.getWithdrawalStack().length, 2);

        assertEq(address(vault.withdrawalStack(0)), address(strategy1));
        assertEq(address(vault.withdrawalStack(1)), address(strategy1));
    }

    function testWithdrawingWithUntrustedStrategyInStack() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        vault.pushToWithdrawalStack(strategy2);
        vault.pushToWithdrawalStack(strategy2);
        vault.pushToWithdrawalStack(new MockERC20Strategy(underlying));
        vault.pushToWithdrawalStack(strategy1);
        vault.pushToWithdrawalStack(strategy1);

        assertEq(vault.getWithdrawalStack().length, 5);

        vault.redeem(1e18, address(this), address(this));

        assertEq(vault.getWithdrawalStack().length, 1);

        assertEq(address(vault.withdrawalStack(0)), address(strategy2));
    }

    function testFailTrustStrategyWithWrongUnderlying() public {
        MockERC20 wrongUnderlying = new MockERC20("Not The Right Token", "TKN2", 18);

        MockERC20Strategy badStrategy = new MockERC20Strategy(wrongUnderlying);

        vault.trustStrategy(badStrategy);
    }

    function testFailTrustStrategyWithETHUnderlying() public {
        MockETHStrategy ethStrategy = new MockETHStrategy();

        vault.trustStrategy(ethStrategy);
    }

    function testFailWithdrawWithEmptyStack() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 1e18);

        vault.redeem(1e18, address(this), address(this));
    }

    function testFailWithdrawWithIncompleteStack() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);

        vault.pushToWithdrawalStack(strategy1);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);

        vault.redeem(1e18, address(this), address(this));
    }

    function testFailInitializeTwice() public {
        vault.initialize();
    }

    function testDestroyVault() public {
        vault.destroy();
    }
}

contract VaultsETHTest is DSTestPlus {
    Vault wethVault;
    WETH weth;

    MockETHStrategy ethStrategy;
    MockERC20Strategy erc20Strategy;

    function setUp() public {
        weth = new WETH();

        wethVault = new VaultFactory(address(this), Authority(address(0))).deployVault(weth);

        wethVault.setFeePercent(0.1e18);
        wethVault.setHarvestDelay(6 hours);
        wethVault.setHarvestWindow(5 minutes);
        wethVault.setTargetFloatPercent(0.01e18);

        wethVault.setUnderlyingIsWETH(true);

        wethVault.initialize();

        ethStrategy = new MockETHStrategy();
        erc20Strategy = new MockERC20Strategy(weth);
    }

    function testAtomicDepositWithdrawIntoETHStrategies() public {
        uint256 startingETHBal = address(this).balance;

        weth.deposit{value: 1 ether}();

        assertEq(address(this).balance, startingETHBal - 1 ether);

        weth.approve(address(wethVault), 1e18);
        wethVault.deposit(1e18, address(this));

        wethVault.trustStrategy(ethStrategy);
        wethVault.depositIntoStrategy(ethStrategy, 0.5e18);
        wethVault.pushToWithdrawalStack(ethStrategy);

        wethVault.trustStrategy(erc20Strategy);
        wethVault.depositIntoStrategy(erc20Strategy, 0.5e18);
        wethVault.pushToWithdrawalStack(erc20Strategy);

        wethVault.withdrawFromStrategy(ethStrategy, 0.25e18);
        wethVault.withdrawFromStrategy(erc20Strategy, 0.25e18);

        wethVault.redeem(1e18, address(this), address(this));

        weth.withdraw(1 ether);

        assertEq(address(this).balance, startingETHBal);
    }

    function testTrustStrategyWithETHUnderlying() public {
        wethVault.trustStrategy(ethStrategy);

        (bool trusted, ) = wethVault.getStrategyData(ethStrategy);
        assertTrue(trusted);
    }

    function testTrustStrategyWithWETHUnderlying() public {
        wethVault.trustStrategy(erc20Strategy);

        (bool trusted, ) = wethVault.getStrategyData(erc20Strategy);
        assertTrue(trusted);
    }

    function testDestroyVaultReturnsETH() public {
        uint256 startingETHBal = address(this).balance;
        payable(address(wethVault)).transfer(1 ether);

        wethVault.destroy();
        assertEq(address(this).balance, startingETHBal);
    }

    receive() external payable {}
}

contract UnInitializedVaultTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vault = new VaultFactory(address(this), Authority(address(0))).deployVault(underlying);

        vault.setFeePercent(0.1e18);
        vault.setHarvestDelay(6 hours);
        vault.setHarvestWindow(5 minutes);
        vault.setTargetFloatPercent(0.01e18);
    }

    function testFailDeposit() public {
        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));
    }

    function testInitializeAndDeposit() public {
        assertFalse(vault.isInitialized());
        assertEq(vault.totalSupply(), type(uint256).max);

        vault.initialize();

        assertTrue(vault.isInitialized());
        assertEq(vault.totalSupply(), 0);

        underlying.mint(address(this), 1e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));
    }
}

// Bound a value between a min and max.
function bound(
    uint256 x,
    uint256 min,
    uint256 max
) pure returns (uint256 result) {
    require(max >= min, "MAX_LESS_THAN_MIN");

    uint256 size = max - min;

    if (max != type(uint256).max) size++; // Make the max inclusive.
    if (size == 0) return min; // Using max would be equivalent as well.
    // Ensure max is inclusive in cases where x != 0 and max is at uint max.
    if (max == type(uint256).max && x != 0) x--; // Accounted for later.

    if (x < min) x += size * (((min - x) / size) + 1);
    result = min + ((x - min) % size);

    // Account for decrementing x to make max inclusive.
    if (max == type(uint256).max && x != 0) result++;
}

function getDiff(uint256 a, uint256 b) pure returns (uint256) {
    return a >= b ? a - b : b - a;
}

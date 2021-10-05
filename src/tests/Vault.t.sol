// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new VaultFactory().deployVault(underlying);
    }

    function testAtomicDepositWithdraw() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18);

        assertEq(vault.exchangeRate(), vault.BASE_UNIT());
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.underlyingBalanceOf(address(this)), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.withdraw(1e18);

        assertEq(vault.exchangeRate(), vault.BASE_UNIT());
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.underlyingBalanceOf(address(this)), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    function testAtomicDepositRedeem() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(vault), 1e18);

        uint256 preDepositBal = underlying.balanceOf(address(this));

        vault.deposit(1e18);

        assertEq(vault.exchangeRate(), vault.BASE_UNIT());
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.underlyingBalanceOf(address(this)), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        vault.redeem(1e18);

        assertEq(vault.exchangeRate(), vault.BASE_UNIT());
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.underlyingBalanceOf(address(this)), 0);
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
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
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {WETH} from "solmate/tokens/WETH.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {VaultETHWrapperModule} from "../modules/VaultETHWrapperModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultETHWrapperModuleTest is DSTestPlus {
    Vault vault;
    WETH underlying;

    VaultETHWrapperModule vaultETHWrapperModule;

    function setUp() public {
        underlying = new WETH();
        vault = new VaultFactory().deployVault(underlying);

        vaultETHWrapperModule = new VaultETHWrapperModule();
    }

    function testAtomicDepositWithdrawETH() public {
        vault.setUnderlyingIsWETH(true);

        uint256 startingETHBal = address(this).balance;

        vaultETHWrapperModule.depositETHIntoVault{value: 1 ether}(vault);

        assertEq(address(this).balance, startingETHBal - 1 ether);

        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 1 ether);

        vault.approve(address(vaultETHWrapperModule), 1e18);
        vaultETHWrapperModule.withdrawETHFromVault(vault, 1 ether);

        assertEq(address(this).balance, startingETHBal);
    }

    function testAtomicDepositRedeemETH() public {
        vault.setUnderlyingIsWETH(true);

        uint256 startingETHBal = address(this).balance;

        vaultETHWrapperModule.depositETHIntoVault{value: 69 ether}(vault);

        assertEq(address(this).balance, startingETHBal - 69 ether);

        assertEq(vault.balanceOf(address(this)), 69e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 69 ether);

        vault.approve(address(vaultETHWrapperModule), 69e19);
        vaultETHWrapperModule.redeemETHFromVault(vault, 69e18);

        assertEq(address(this).balance, startingETHBal);
    }

    function testFailDepositIntoNotWETHVault() public {
        vaultETHWrapperModule.depositETHIntoVault{value: 1 ether}(vault);
    }

    function testFailWithdrawFromNotWETHVault() public {
        vault.setUnderlyingIsWETH(true);

        vaultETHWrapperModule.depositETHIntoVault{value: 1 ether}(vault);

        vault.setUnderlyingIsWETH(false);

        vault.approve(address(vaultETHWrapperModule), 1e18);

        vaultETHWrapperModule.withdrawETHFromVault(vault, 1 ether);
    }

    function testFailRedeemFromNotWETHVault() public {
        vault.setUnderlyingIsWETH(true);

        vaultETHWrapperModule.depositETHIntoVault{value: 1 ether}(vault);

        vault.setUnderlyingIsWETH(false);

        vault.approve(address(vaultETHWrapperModule), 1e18);

        vaultETHWrapperModule.redeemETHFromVault(vault, 1e18);
    }

    receive() external payable {}
}

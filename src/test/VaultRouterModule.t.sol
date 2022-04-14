// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {WETH} from "solmate/tokens/WETH.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {VaultRouterModule} from "../modules/VaultRouterModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultRouterModuleTest is DSTestPlus {
    Vault wethVault;
    WETH weth;

    VaultRouterModule vaultRouterModule;

    function setUp() public {
        weth = new WETH();

        wethVault = new VaultFactory(address(this), Authority(address(0))).deployVault(weth);

        wethVault.initialize();

        vaultRouterModule = new VaultRouterModule();
    }

    /*///////////////////////////////////////////////////////////////
                      ETH DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicDepositWithdrawETH() public {
        wethVault.setUnderlyingIsWETH(true);

        uint256 startingETHBal = address(this).balance;

        vaultRouterModule.depositETHIntoVault{value: 1 ether}(wethVault);

        assertEq(address(this).balance, startingETHBal - 1 ether);

        assertEq(wethVault.balanceOf(address(this)), 1e18);
        assertEq(wethVault.convertToAssets((10**wethVault.decimals())), 1 ether);

        wethVault.approve(address(vaultRouterModule), 1e18);
        vaultRouterModule.withdrawETHFromVault(wethVault, 1 ether);

        assertEq(address(this).balance, startingETHBal);
    }

    function testAtomicDepositRedeemETH() public {
        wethVault.setUnderlyingIsWETH(true);

        uint256 startingETHBal = address(this).balance;

        vaultRouterModule.depositETHIntoVault{value: 69 ether}(wethVault);

        assertEq(address(this).balance, startingETHBal - 69 ether);

        assertEq(wethVault.balanceOf(address(this)), 69e18);
        assertEq((wethVault.convertToAssets(wethVault.balanceOf(address(this)))), 69 ether);

        wethVault.approve(address(vaultRouterModule), 69e19);
        vaultRouterModule.redeemETHFromVault(wethVault, 69e18);

        assertEq(address(this).balance, startingETHBal);
    }

    /*///////////////////////////////////////////////////////////////
               ETH DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositIntoNotWETHVault() public {
        vaultRouterModule.depositETHIntoVault{value: 1 ether}(wethVault);
    }

    function testFailWithdrawFromNotWETHVault() public {
        wethVault.setUnderlyingIsWETH(true);

        vaultRouterModule.depositETHIntoVault{value: 1 ether}(wethVault);

        wethVault.setUnderlyingIsWETH(false);

        wethVault.approve(address(vaultRouterModule), 1e18);

        vaultRouterModule.withdrawETHFromVault(wethVault, 1 ether);
    }

    function testFailRedeemFromNotWETHVault() public {
        wethVault.setUnderlyingIsWETH(true);

        vaultRouterModule.depositETHIntoVault{value: 1 ether}(wethVault);

        wethVault.setUnderlyingIsWETH(false);

        wethVault.approve(address(vaultRouterModule), 1e18);

        vaultRouterModule.redeemETHFromVault(wethVault, 1e18);
    }

    receive() external payable {}
}

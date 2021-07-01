// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {StringConcat} from "../libraries/StringConcat.sol";

import {Vault} from "../Vault.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20();
        vault = new Vault(underlying);
    }

    function test_properly_init_erc20() public {
        assertErc20Eq(vault.underlying(), underlying);

        assertEq(vault.name(), StringConcat.concat("Fuse ", underlying.name(), " Vault"));

        assertEq(vault.symbol(), StringConcat.concat("fv", underlying.symbol()));
    }

    function test_exchange_rate_is_initially_one(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > type(uint256).max / 1e36) return;

        underlying.mintIfNeeded(self, amount);
        underlying.approve(address(vault), amount);
        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);

        assertEq(underlying.balanceOf(address(vault)), vault.balanceOf(self));
        assertEq(vault.exchangeRateCurrent(), 1e18);
    }

    function test_exchange_rate_increases(uint256 amount) public {
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mintIfNeeded(self, amount * 2);
        underlying.approve(address(vault), amount);
        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);
        // Send tokens into the vault, artificially increasing the exchangeRate.
        underlying.transfer(address(vault), amount);

        assertEq(vault.exchangeRateCurrent(), 2e18);
    }
}

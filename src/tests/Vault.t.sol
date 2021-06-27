// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {StringConcat} from "../libraries/StringConcat.sol";

import {Vault} from "../Vault.sol";

contract VaultsTest is DSTest {
    Vault vault;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20();
        vault = new Vault(underlying);
    }

    function test_properly_init_erc20() public {
        assertEq(address(vault.underlying()), address(underlying));

        assertEq(vault.name(), StringConcat.concat("Fuse ", underlying.name(), " Vault"));

        assertEq(vault.symbol(), StringConcat.concat("fv", underlying.symbol()));
    }

    function test_exchange_rate_is_initially_one() public {
        // 10 tokens
        uint256 amount = 1e19;
        underlying.mintIfNeeded(address(this), amount);
        underlying.approve(address(vault), amount);
        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);

        assertEq(vault.totalUnderlying(), vault.balanceOf(address(this)));
    }

    function test_exchange_rate_increases() public {
        uint256 amount = 1e19;
        underlying.mintIfNeeded(address(this), 2 * amount);
        underlying.approve(address(vault), amount);

        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);
        // Send tokens into the vault, artificially increasing the exchangeRate.
        underlying.transfer(address(vault), amount);

        assertEq(vault.exchangeRateCurrent(), 2e18);
    }
}

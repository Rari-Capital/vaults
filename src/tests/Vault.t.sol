// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

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

        assertEq(vault.name(), string(abi.encodePacked("Fuse ", underlying.name(), " Vault")));
        assertEq(vault.symbol(), string(abi.encodePacked("fv", underlying.symbol())));
    }

    function test_exchange_rate_is_initially_one(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > type(uint256).max / 1e36) return;

        underlying.mint(self, amount);
        underlying.approve(address(vault), amount);

        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);

        assertEq(vault.exchangeRateCurrent(), 10**underlying.decimals());
    }

    function test_exchange_rate_increases(uint256 amount) public {
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount * 2);
        underlying.approve(address(vault), amount);

        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);

        assertEq(vault.exchangeRateCurrent(), 10**underlying.decimals());

        // Send tokens into the vault, artificially increasing the exchangeRate.
        underlying.transfer(address(vault), amount);

        assertEq(vault.exchangeRateCurrent(), 2 * 10**underlying.decimals());
    }

    function test_underlying_withdrawals_function_properly(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount);
        underlying.approve(address(vault), amount);

        // Deposit into the vault.
        vault.deposit(amount);

        // Can withdraw full balance from the vault.
        vault.withdrawUnderlying(amount);

        // fvTokens are set to 0.
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(underlying.balanceOf(address(this)), amount);

        // TODO: Add balanceOfUnderlying function.
    }

    function test_withdrawals_function_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount * 2);

        // Artificially inflate the exchange rate.
        underlying.transfer(address(vault), amount);

        // Deposit into the vault.
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        // Withdraw full balance of fvTokens.
        vault.withdraw(vault.balanceOf(address(this)));

        // Assert that all fvTokens have been burned.
        assertEq(vault.totalSupply(), 0);

        // Assert that the full underlying balance has been returned.
        assertEq(underlying.balanceOf(address(this)), 2 * amount);
    }
}

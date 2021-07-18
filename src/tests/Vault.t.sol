// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {Vault} from "../Vault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockCERC20} from "./mocks/MockCERC20.sol";
import {CErc20} from "../external/CErc20.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;
    CErc20 cToken;

    function setUp() public {
        underlying = new MockERC20();
        vault = new Vault(underlying);
        cToken = CErc20(address(new MockCERC20(underlying)));
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

    function test_exchange_rate_is_not_affected_by_deposits() public {
        uint256 amount = 999999999999999999;
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount * 3);

        // Deposit into the vault, minting fvTokens.
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        // Artificially increase the exchange rate.
        underlying.transfer(address(vault), amount);

        // Ensure the exchange rate is equal to 2
        assertEq(vault.exchangeRateCurrent(), 2 * 10**underlying.decimals());

        // Deposit into the vault, minting fvTokens.
        underlying.approve(address(vault), amount);
        emit log_uint(vault.exchangeRateCurrent());
        vault.deposit(amount);

        emit log_uint(vault.exchangeRateCurrent());
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

    function test_enter_pool_functions_properly() public {
        test_exchange_rate_is_initially_one(1e18);
        emit log_uint(vault.totalSupply());
        vault.enterPool(cToken, 1e18);
    }
}

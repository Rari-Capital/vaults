// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {MockCERC20} from "./mocks/MockCERC20.sol";

import {Vault} from "../Vault.sol";
import {CErc20} from "../external/CErc20.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;
    CErc20 cToken;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);
        // todo: can we make mockcerc20 just conform to cerc20 lol
        cToken = CErc20(address(new MockCERC20(underlying)));
    }

    function test_properly_init_erc20() public {
        assertERC20Eq(vault.underlying(), underlying);

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
        assertEq(vault.balanceOf(self), 0);
        assertEq(underlying.balanceOf(self), amount);

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
        vault.withdraw(vault.balanceOf(self));

        // Assert that all fvTokens have been burned.
        assertEq(vault.totalSupply(), 0);

        // Assert that the full underlying balance has been returned.
        assertEq(underlying.balanceOf(self), 2 * amount);
    }

    function test_enter_pool_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        test_exchange_rate_is_initially_one(amount);
        vault.enterPool(cToken, amount);
    }

    function test_exit_pool_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        test_enter_pool_functions_properly(amount);
        vault.exitPool(0, amount);
    }

    function test_harvest_functional_properly() public {
        uint256 amount = 162931130;
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        test_exchange_rate_is_initially_one(amount / 2);

        for (uint256 i = 0; i < 10; i++) {
            CErc20 mockCErc20 = CErc20(address(new MockCERC20(underlying)));

            // Deposit 5% of the total supply into the vault.
            // This ensure that by the end of the loop, 100% of the vault balance is deposited into various cTokens.
            vault.enterPool(mockCErc20, amount / 20);

            // Artificially inflate the CErc20 balance.
            //underlying.transfer(address(mockCErc20), amount / 20);
        }

        vault.harvest();
    }
}

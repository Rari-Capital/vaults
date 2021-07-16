// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {ERC20} from "../external/ERC20.sol";
import {Vault} from "../Vault.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    ERC20 underlying;

    function setUp() public {
        underlying = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
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
        underlying.approve(address(vault), amount);

        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);

        assertEq(vault.exchangeRateCurrent(), 10**underlying.decimals());
    }

    function test_exchange_rate_increases(uint256 amount) public {
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

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
        if (amount > (type(uint256).max / 1e37)) return;

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
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {MockCERC20} from "./mocks/MockCERC20.sol";
import {MockWETH, MockCETH} from "./mocks/MockCETH.sol";

import {Vault} from "../Vault.sol";
import {CErc20} from "../external/CErc20.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;
    CErc20 cToken;
    CErc20[] withdrawQueue;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);

        vault.setFeeClaimer(address(1));
        // todo: can we make mockcerc20 just conform to cerc20 lol
        cToken = CErc20(address(new MockCERC20(underlying)));
    }

    // TODO: Use other test functions instead of copying and pasting test logic.

    function test_properly_init_erc20() public {
        assertERC20Eq(vault.underlying(), underlying);

        assertEq(vault.name(), string(abi.encodePacked("Fuse ", underlying.name(), " Vault")));
        assertEq(vault.symbol(), string(abi.encodePacked("fv", underlying.symbol())));
    }

    function test_deposits_function_correctly(uint256 amount) public {
        if (amount > type(uint256).max / 1e36) return;

        // Mint underlying tokens to deposit into the vault.
        underlying.mint(self, amount);

        // Approve underlying tokens.
        underlying.approve(address(vault), amount);

        // Deposit into the vault, minting fvTokens.
        vault.deposit(amount);
    }

    function test_exchange_rate_is_initially_one(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > type(uint256).max / 1e36) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        assertEq(vault.exchangeRateCurrent(), 10**underlying.decimals());
    }

    function test_exchange_rate_increases(uint256 amount) public {
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount);

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        // Assert that the initial exchange rate is 1.
        assertEq(vault.exchangeRateCurrent(), 10**underlying.decimals());

        // Send tokens into the vault, artificially increasing the exchangeRate.
        underlying.transfer(address(vault), amount);

        // Assert that exchange rate increases when the Vault "accrues" tokens.
        assertEq(vault.exchangeRateCurrent(), 2 * 10**underlying.decimals());
    }

    function test_exchange_rate_is_not_affected_by_deposits(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 1e18) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        underlying.mint(self, amount);
        underlying.transfer(address(vault), amount);

        // Ensure the exchange rate is equal to 2
        assertEq(vault.exchangeRateCurrent(), 2e18);

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        assertEq(vault.exchangeRateCurrent(), 2e18);
    }

    function test_underlying_withdrawals_function_properly(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        // Can withdraw full balance from the vault.
        vault.withdrawUnderlying(amount);

        // fvTokens are set to 0.
        assertEq(vault.balanceOf(self), 0);
        assertEq(underlying.balanceOf(self), amount);

        // TODO: Add balanceOfUnderlying function.
    }

    function test_withdrawals_function_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        // Artificially inflate the exchange rate.
        underlying.mint(self, amount);
        underlying.transfer(address(vault), amount);

        // Assert that the full token supply has been deposited into the Tank.
        assertEq(underlying.balanceOf(address(vault)), underlying.totalSupply());

        // Withdraw full balance of fvTokens.
        vault.withdraw(vault.balanceOf(self));

        // Assert that all fvTokens have been burned.
        assertEq(vault.totalSupply(), 0);

        // Assert that the full underlying balance has been returned.
        assertEq(underlying.balanceOf(self), underlying.totalSupply());
    }

    function test_enter_pool_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);
        vault.enterPool(cToken, amount);
    }

    function test_exit_pool_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        test_enter_pool_functions_properly(amount);
        vault.exitPool(0, amount);
    }

    function test_exit_pool_max_balance_withdrawal_functions_properly() public {
        uint256 amount = 1e18;
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        test_enter_pool_functions_properly(amount);
        vault.exitPool(0, type(uint256).max);
    }

    function test_harvest_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 40) return;

        // Mint, approve, and deposit tokens into the vault.
        test_deposits_function_correctly(amount);

        // Set the block number to 1.
        // If the current block number is 0, the vault will act unexpectedly.
        hevm.roll(1);

        // Allocate the deposited tokens to various cToken contracts.
        for (uint256 i = 0; i < 10; i++) {
            // Deploy a new mock cToken contract and add it to the withdrawQueue.
            CErc20 mockCErc20 = CErc20(address(new MockCERC20(underlying)));
            withdrawQueue.push(mockCErc20);

            // Deposit 10% of the total supply into the vault.
            // This ensure that by the end of the loop, 100% of the vault balance is deposited into the cTokens contracts.
            vault.enterPool(mockCErc20, amount / 10);

            // Transfer tokens to the cToken contract to simulate earned interest.
            // This simulates a 50% increase.
            underlying.mint(address(this), amount / 20);
            underlying.transfer(address(mockCErc20), amount / 20);
        }

        // Set the withdrawalQueue to the token addresses.
        vault.setWithdrawalQueue(withdrawQueue);

        // Trigger a harvest.
        vault.harvest();
    }

    function test_harvest_profits_are_correctly_calculated(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 10000) return;

        test_harvest_functions_properly(amount);

        // Assert that the exchangeRate maintains the same value after the harvest.
        assertEq(vault.exchangeRateCurrent(), 1e18);

        // Forward block number to middle of the harvest.
        hevm.roll(block.number + (vault.minimumHarvestDelay() / 2));

        // Assert that the exchange rate is between 1.24 and 1.26
        uint256 exchangeRate = vault.exchangeRateCurrent();
        assertTrue(exchangeRate > 1.24e18 && exchangeRate < 1.26e18);

        // Emit the current exchange rate
        // Expected: between 1.4e18 and 1.5e18
        hevm.roll(block.number + (vault.minimumHarvestDelay() / 2));

        // Assert that the exchange rate is greater than 1.499 and less than or equal to 1.5.
        exchangeRate = vault.exchangeRateCurrent();
        assertTrue(exchangeRate > 1.499e18 && exchangeRate <= 1.5e18);
    }

    function test_harvest_fees_are_correctly_calculated() public {
        uint256 amount = 1e18;

        if (amount > (type(uint256).max / 1e37) || amount < 40) return;

        test_harvest_functions_properly(amount);

        // Emit the current exchange rate
        // Expected: between 1.4e18 and 1.5e18
        hevm.roll(block.number + vault.minimumHarvestDelay());

        vault.harvest();
        uint256 feesTaken = vault.balanceOfUnderlying(address(1));
        assertTrue(feesTaken > 0.0099e18 && feesTaken < 0.01e18);
    }

    function test_harvest_pulls_into_float(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 1000) return;

        test_harvest_functions_properly(amount);

        // Calculate the expected float after the harvest.
        uint256 expectedFloat = (amount * vault.targetFloatPercent()) / 1e18;

        // Assert the vault matches the expected float.
        assertEq(expectedFloat, vault.getFloat());

        // Ensure that pulling into the float does not modify the exchange rate.
        assertEq(vault.exchangeRateCurrent(), 1e18);
    }

    function test_enter_pool_weth_functions_correctly() public {
        uint256 amount = 1e18;
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying = MockERC20(address(new MockWETH()));
        vault = new Vault(underlying);
        cToken = CErc20(address(new MockCETH()));

        test_deposits_function_correctly(amount);
        vault.enterPool(cToken, amount);
    }

    function test_exit_pool_weth_functions_correctly() public {}

    // TODO: Add WETH tests
    // TODO: Add tests for setter functions
}

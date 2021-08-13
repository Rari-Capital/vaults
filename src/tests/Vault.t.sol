// SPDX-License-Identifier: AGPL-3.0-only
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
    CErc20[] withdrawQueue;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);

        vault.setFeeClaimer(address(1));
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
        uint256 amount = 1e18;
        // If the number is too large or 0 we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        underlying.mint(self, amount * 3);

        // Deposit into the vault, minting fvTokens.
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        underlying.transfer(address(vault), amount);

        // Ensure the exchange rate is equal to 2
        assertEq(vault.exchangeRateCurrent(), 2e18);

        // Deposit into the vault, minting fvTokens.
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        assertEq(vault.exchangeRateCurrent(), 2e18);
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

    function test_harvest_functions_properly(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 40) return;

        // Deposit underlying tokens into the vault.
        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

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
            underlying.mint(address(this), amount / 40);
            underlying.transfer(address(mockCErc20), amount / 40);
        }

        // Set the withdrawalQueue to the token addresses.
        vault.setWithdrawalQueue(withdrawQueue);

        // Trigger a harvest.
        vault.harvest();

        // Forward the block number to block.number + vault.minimumHarvestDelay() to simulate a full harvest.
        hevm.roll(block.number + vault.minimumHarvestDelay());

        // Assert that the vault's exchange rate has increased 1.
        assertGt(vault.exchangeRateCurrent(), 1e18);
    }

    function test_harvest_profits_are_correctly_calculated(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 10000) return;

        // Deposit into the vault.
        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

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

        // Set the withdrawalQueue to an array of cToken addresses.
        vault.setWithdrawalQueue(withdrawQueue);

        // Trigger a harvest.
        vault.harvest();

        // Assert that the exchangeRate maintains the same value after the harvest.
        assertEq(vault.exchangeRateCurrent(), 1e18);

        // Forward block number to middle of the harvest.
        hevm.roll(block.number + (vault.minimumHarvestDelay() / 2));

        // Emit the current exchange rate
        // Expected: between 1e18 and 1.5e18
        emit log_named_uint("Exchange rate after half harvest", vault.exchangeRateCurrent());
        uint256 exchangeRate = vault.exchangeRateCurrent();
        assertTrue(exchangeRate > 1.24e18 && exchangeRate < 1e26);

        // Emit the current exchange rate
        // Expected: between 1.4e18 and 1.5e18
        hevm.roll(block.number + vault.minimumHarvestDelay());

        exchangeRate = vault.exchangeRateCurrent();
        assertTrue(exchangeRate > 1.499e18 && exchangeRate <= 1.5e18);
    }

    function test_harvest_fees_are_correctly_calculated() public {
        uint256 amount = 1e18;

        if (amount > (type(uint256).max / 1e37) || amount < 40) return;

        // Deposit into the vault.
        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        // Set the block number to 1.
        // If the current block number is 1, the vault will act unexpectedly.
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

        // Forward block number to middle of the harvest.
        hevm.roll(block.number + (vault.minimumHarvestDelay() / 2));

        // Emit the current exchange rate
        // Expected: between 1.4e18 and 1.5e18
        hevm.roll(block.number + vault.minimumHarvestDelay());

        emit log_uint((vault.maxLockedProfit() * vault.feePercentage()) / 1e18);
        vault.harvest();
        emit log_named_uint("Expected fee amount", (vault.feePercentage() * 0.5e18) / 1e18);

        uint256 feesTaken = vault.balanceOfUnderlying(address(1));
        assertTrue(feesTaken > 0.0099e18 && feesTaken < 0.01e18);
        emit log_uint(feesTaken);
        emit log_uint(vault.balanceOf(address(1)));
    }

    function test_harvest_pulls_into_float(uint256 amount) public {
        if (amount > (type(uint256).max / 1e37) || amount < 1000) return;

        // Deposit into the vault.
        underlying.mint(address(this), amount);
        underlying.approve(address(vault), amount);
        vault.deposit(amount);

        // Set the block number to 1.
        // If the current block number is 1, the vault will act unexpectedly.
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

        uint256 expectedFloat = (vault.calculateTotalFreeUnderlying() * vault.targetFloatPercent()) / 1e18;

        // Trigger a harvest.
        vault.harvest();

        assertEq(expectedFloat, vault.getFloat());
    }

    function test_vault_enter_pool_functions_correctly(uint256 amount) public {}

    function test_vault_exit_pool_functions_correctly(uint256 amount) public {}
}

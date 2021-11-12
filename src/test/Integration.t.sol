// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockERC20Strategy} from "./mocks/MockERC20Strategy.sol";

import {VaultCreationModule} from "../modules/VaultCreationModule.sol";
import {VaultAuthorityModule} from "../modules/VaultAuthorityModule.sol";
import {VaultConfigurationModule} from "../modules/VaultConfigurationModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract IntegrationTest is DSTestPlus {
    VaultFactory vaultFactory;

    VaultAuthorityModule vaultAuthorityModule;

    VaultConfigurationModule vaultConfigurationModule;

    VaultCreationModule vaultCreationModule;

    MockERC20 underlying;

    MockERC20Strategy strategy1;
    MockERC20Strategy strategy2;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vaultAuthorityModule = new VaultAuthorityModule(address(this), Authority(address(0)));

        vaultFactory = new VaultFactory(address(this), vaultAuthorityModule);

        vaultConfigurationModule = new VaultConfigurationModule(address(this), Authority(address(0)));

        vaultCreationModule = new VaultCreationModule(
            vaultFactory,
            vaultConfigurationModule,
            address(this),
            Authority(address(0))
        );

        strategy1 = new MockERC20Strategy(underlying);
        strategy2 = new MockERC20Strategy(underlying);
    }

    function testIntegration() public {
        vaultAuthorityModule.setUserRole(address(vaultConfigurationModule), 0, true);
        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, true);
        vaultAuthorityModule.setRoleCapability(0, Vault.setHarvestDelay.selector, true);
        vaultAuthorityModule.setRoleCapability(0, Vault.setHarvestWindow.selector, true);
        vaultAuthorityModule.setRoleCapability(0, Vault.setTargetFloatPercent.selector, true);

        vaultAuthorityModule.setUserRole(address(vaultCreationModule), 1, true);
        vaultAuthorityModule.setRoleCapability(1, Vault.initialize.selector, true);

        vaultConfigurationModule.setDefaultFeePercent(0.1e18);
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        Vault vault = vaultCreationModule.createVault(underlying);

        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);
        vault.pushToWithdrawalQueue(strategy1);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);
        vault.pushToWithdrawalQueue(strategy2);

        vaultConfigurationModule.setDefaultFeePercent(0.2e18);
        assertEq(vault.feePercent(), 0.1e18);

        vaultConfigurationModule.syncFeePercent(vault);
        assertEq(vault.feePercent(), 0.2e18);

        underlying.transfer(address(strategy1), 0.25e18);
        vault.harvest(strategy1);

        underlying.transfer(address(strategy2), 0.25e18);
        vault.harvest(strategy2);

        hevm.warp(block.timestamp + 6 hours);

        vault.withdraw(1373626373626373626);
        assertEq(vault.balanceOf(address(this)), 0);
    }
}

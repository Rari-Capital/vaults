// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MultiRolesAuthority} from "solmate/auth/authorities/MultiRolesAuthority.sol";

import {MockERC20Strategy} from "./mocks/MockERC20Strategy.sol";

import {VaultInitializationModule} from "../modules/VaultInitializationModule.sol";
import {VaultConfigurationModule} from "../modules/VaultConfigurationModule.sol";

import {Strategy} from "../interfaces/Strategy.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract IntegrationTest is DSTestPlus {
    VaultFactory vaultFactory;

    MultiRolesAuthority multiRolesAuthority;

    VaultConfigurationModule vaultConfigurationModule;

    VaultInitializationModule vaultInitializationModule;

    MockERC20 underlying;

    MockERC20Strategy strategy1;
    MockERC20Strategy strategy2;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        multiRolesAuthority = new MultiRolesAuthority(address(this), Authority(address(0)));

        vaultFactory = new VaultFactory(address(this), multiRolesAuthority);

        vaultConfigurationModule = new VaultConfigurationModule(address(this), Authority(address(0)));

        vaultInitializationModule = new VaultInitializationModule(
            vaultConfigurationModule,
            address(this),
            Authority(address(0))
        );

        strategy1 = new MockERC20Strategy(underlying);
        strategy2 = new MockERC20Strategy(underlying);
    }

    function testIntegration() public {
        multiRolesAuthority.setUserRole(address(vaultConfigurationModule), 0, true);
        multiRolesAuthority.setRoleCapability(0, Vault.setFeePercent.selector, true);
        multiRolesAuthority.setRoleCapability(0, Vault.setHarvestDelay.selector, true);
        multiRolesAuthority.setRoleCapability(0, Vault.setHarvestWindow.selector, true);
        multiRolesAuthority.setRoleCapability(0, Vault.setTargetFloatPercent.selector, true);

        multiRolesAuthority.setUserRole(address(vaultInitializationModule), 1, true);
        multiRolesAuthority.setRoleCapability(1, Vault.initialize.selector, true);

        vaultConfigurationModule.setDefaultFeePercent(0.1e18);
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        Vault vault = vaultFactory.deployVault(underlying);
        vaultInitializationModule.initializeVault(vault);

        underlying.mint(address(this), 1.5e18);

        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18);

        vault.trustStrategy(strategy1);
        vault.depositIntoStrategy(strategy1, 0.5e18);
        vault.pushToWithdrawalStack(strategy1);

        vault.trustStrategy(strategy2);
        vault.depositIntoStrategy(strategy2, 0.5e18);
        vault.pushToWithdrawalStack(strategy2);

        vaultConfigurationModule.setDefaultFeePercent(0.2e18);
        assertEq(vault.feePercent(), 0.1e18);

        vaultConfigurationModule.syncFeePercent(vault);
        assertEq(vault.feePercent(), 0.2e18);

        underlying.transfer(address(strategy1), 0.25e18);

        Strategy[] memory strategiesToHarvest = new Strategy[](2);
        strategiesToHarvest[0] = strategy1;
        strategiesToHarvest[1] = strategy2;

        underlying.transfer(address(strategy2), 0.25e18);
        vault.harvest(strategiesToHarvest);

        hevm.warp(block.timestamp + vault.harvestDelay());

        vault.withdraw(1363636363636363636);
        assertEq(vault.balanceOf(address(this)), 0);
    }
}

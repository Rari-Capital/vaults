// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockAuthority} from "solmate/test/utils/mocks/MockAuthority.sol";

import {VaultInitializationModule} from "../modules/VaultInitializationModule.sol";
import {VaultConfigurationModule} from "../modules/VaultConfigurationModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultInitializationModuleTest is DSTestPlus {
    VaultFactory vaultFactory;

    VaultConfigurationModule vaultConfigurationModule;

    VaultInitializationModule vaultInitializationModule;

    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vaultFactory = new VaultFactory(address(this), new MockAuthority(true));

        vaultConfigurationModule = new VaultConfigurationModule(address(this), Authority(address(0)));

        vaultInitializationModule = new VaultInitializationModule(
            vaultConfigurationModule,
            address(this),
            Authority(address(0))
        );
    }

    function testVaultCreation() public {
        vaultConfigurationModule.setDefaultFeePercent(0.1e18);
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        Vault vault = vaultFactory.deployVault(underlying);

        assertFalse(vault.isInitialized());
        assertEq(vault.feePercent(), 0);
        assertEq(vault.harvestDelay(), 0);
        assertEq(vault.harvestWindow(), 0);
        assertEq(vault.targetFloatPercent(), 0);

        vaultInitializationModule.initializeVault(vault);

        assertTrue(vault.isInitialized());
        assertEq(vault.feePercent(), 0.1e18);
        assertEq(vault.harvestDelay(), 6 hours);
        assertEq(vault.harvestWindow(), 5 minutes);
        assertEq(vault.targetFloatPercent(), 0.01e18);
    }

    function testSetConfigurationModule() public {
        vaultInitializationModule.setConfigModule(VaultConfigurationModule(address(0xBEEF)));

        assertEq(address(vaultInitializationModule.configModule()), address(0xBEEF));
    }
}

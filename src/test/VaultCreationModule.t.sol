// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {TrustAuthority} from "solmate/auth/authorities/TrustAuthority.sol";

import {VaultCreationModule} from "../modules/VaultCreationModule.sol";
import {VaultConfigurationModule} from "../modules/VaultConfigurationModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultCreationModuleTest is DSTestPlus {
    VaultFactory vaultFactory;

    TrustAuthority trustAuthority;

    VaultConfigurationModule vaultConfigurationModule;

    VaultCreationModule vaultCreationModule;

    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        trustAuthority = new TrustAuthority(address(this));

        vaultFactory = new VaultFactory(address(this), trustAuthority);

        vaultConfigurationModule = new VaultConfigurationModule(address(this), Authority(address(0)));

        vaultCreationModule = new VaultCreationModule(
            vaultFactory,
            vaultConfigurationModule,
            address(this),
            Authority(address(0))
        );

        trustAuthority.setIsTrusted(address(vaultCreationModule), true);
        trustAuthority.setIsTrusted(address(vaultConfigurationModule), true);
    }

    function testVaultCreation() public {
        vaultConfigurationModule.setDefaultFeePercent(0.1e18);
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        Vault vault = vaultCreationModule.createVault(underlying);

        assertTrue(vault.isInitialized());

        assertEq(vault.feePercent(), 0.1e18);
        assertEq(vault.harvestDelay(), 6 hours);
        assertEq(vault.harvestWindow(), 5 minutes);
        assertEq(vault.targetFloatPercent(), 0.01e18);
    }

    function testSetConfigurationModule() public {
        vaultCreationModule.setConfigModule(VaultConfigurationModule(address(0xBEEF)));

        assertEq(address(vaultCreationModule.configModule()), address(0xBEEF));
    }
}

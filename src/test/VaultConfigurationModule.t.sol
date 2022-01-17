// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockAuthority} from "solmate/test/utils/mocks/MockAuthority.sol";

import {VaultConfigurationModule} from "../modules/VaultConfigurationModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultConfigurationModuleTest is DSTestPlus {
    VaultFactory vaultFactory;

    Vault vault;
    MockERC20 underlying;

    VaultConfigurationModule vaultConfigurationModule;

    function setUp() public {
        vaultConfigurationModule = new VaultConfigurationModule(address(this), Authority(address(0)));

        vaultFactory = new VaultFactory(address(this), new MockAuthority(true));

        underlying = new MockERC20("Mock Token", "TKN", 18);

        vault = vaultFactory.deployVault(underlying);
    }

    /*///////////////////////////////////////////////////////////////
                          DEFAULT SETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetDefaultFeePercent() public {
        vaultConfigurationModule.setDefaultFeePercent(0.1e18);

        assertEq(vaultConfigurationModule.defaultFeePercent(), 0.1e18);

        vaultConfigurationModule.syncFeePercent(vault);

        assertEq(vault.feePercent(), 0.1e18);
    }

    function testSetDefaultHarvestDelay() public {
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);

        assertEq(vaultConfigurationModule.defaultHarvestDelay(), 6 hours);

        vaultConfigurationModule.syncHarvestDelay(vault);

        assertEq(vault.harvestDelay(), 6 hours);
    }

    function testSetDefaultHarvestWindow() public {
        // Harvest delay has to be set before harvest window.
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.syncHarvestDelay(vault);

        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);

        assertEq(vaultConfigurationModule.defaultHarvestWindow(), 5 minutes);

        vaultConfigurationModule.syncHarvestWindow(vault);

        assertEq(vault.harvestWindow(), 5 minutes);
    }

    function testSetDefaultTargetFloatPercent() public {
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        assertEq(vaultConfigurationModule.defaultTargetFloatPercent(), 0.01e18);

        vaultConfigurationModule.syncTargetFloatPercent(vault);

        assertEq(vault.targetFloatPercent(), 0.01e18);
    }

    /*///////////////////////////////////////////////////////////////
                         CUSTOM SETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetCustomFeePercent() public {
        vaultConfigurationModule.setVaultCustomFeePercent(vault, 0.1e18);

        assertEq(vaultConfigurationModule.getVaultCustomFeePercent(vault), 0.1e18);

        vaultConfigurationModule.syncFeePercent(vault);

        assertEq(vault.feePercent(), 0.1e18);
    }

    function testSetCustomHarvestDelay() public {
        vaultConfigurationModule.setVaultCustomHarvestDelay(vault, 6 hours);

        assertEq(vaultConfigurationModule.getVaultCustomHarvestDelay(vault), 6 hours);

        vaultConfigurationModule.syncHarvestDelay(vault);

        assertEq(vault.harvestDelay(), 6 hours);
    }

    function testSetCustomHarvestWindow() public {
        // Harvest delay has to be set before harvest window.
        vaultConfigurationModule.setVaultCustomHarvestDelay(vault, 6 hours);
        vaultConfigurationModule.syncHarvestDelay(vault);

        vaultConfigurationModule.setVaultCustomHarvestWindow(vault, 5 minutes);

        assertEq(vaultConfigurationModule.getVaultCustomHarvestWindow(vault), 5 minutes);

        vaultConfigurationModule.syncHarvestWindow(vault);

        assertEq(vault.harvestWindow(), 5 minutes);
    }

    function testSetCustomTargetFloatPercent() public {
        vaultConfigurationModule.setVaultCustomTargetFloatPercent(vault, 0.01e18);

        assertEq(vaultConfigurationModule.getVaultCustomTargetFloatPercent(vault), 0.01e18);

        vaultConfigurationModule.syncTargetFloatPercent(vault);

        assertEq(vault.targetFloatPercent(), 0.01e18);
    }

    /*///////////////////////////////////////////////////////////////
                    CUSTOM OVERRIDES DEFAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function tesCustomFeePercentOverridesDefault() public {
        vaultConfigurationModule.setVaultCustomFeePercent(vault, 0.1e18);

        vaultConfigurationModule.setDefaultFeePercent(0.2e18);

        vaultConfigurationModule.syncFeePercent(vault);

        assertEq(vault.feePercent(), 0.1e18);
    }

    function testCustomHarvestDelayOverridesDefault() public {
        vaultConfigurationModule.setVaultCustomHarvestDelay(vault, 6 hours);

        vaultConfigurationModule.setDefaultHarvestDelay(5 hours);

        vaultConfigurationModule.syncHarvestDelay(vault);

        assertEq(vault.harvestDelay(), 6 hours);
    }

    function testCustomHarvestWindowOverridesDefault() public {
        // Harvest delay has to be set before harvest window.
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.syncHarvestDelay(vault);

        vaultConfigurationModule.setVaultCustomHarvestWindow(vault, 5 minutes);

        vaultConfigurationModule.setDefaultHarvestWindow(10 minutes);

        vaultConfigurationModule.syncHarvestWindow(vault);

        assertEq(vault.harvestWindow(), 5 minutes);
    }

    function testCustomTargetFloatPercentOverridesDefault() public {
        vaultConfigurationModule.setVaultCustomTargetFloatPercent(vault, 0.01e18);

        vaultConfigurationModule.setDefaultTargetFloatPercent(0.02e18);

        vaultConfigurationModule.syncTargetFloatPercent(vault);

        assertEq(vault.targetFloatPercent(), 0.01e18);
    }

    /*///////////////////////////////////////////////////////////////
                DEFAULT OVERRIDES CUSTOM OF ZERO TESTS 
    //////////////////////////////////////////////////////////////*/

    function testDefaultFeePercentOverridesCustomOfZero() public {
        vaultConfigurationModule.setDefaultFeePercent(0.1e18);

        vaultConfigurationModule.setVaultCustomFeePercent(vault, 0);

        vaultConfigurationModule.syncFeePercent(vault);

        assertEq(vault.feePercent(), 0.1e18);
    }

    function testDefaultHarvestDelayOverridesCustomOfZero() public {
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);

        vaultConfigurationModule.setVaultCustomHarvestDelay(vault, 0);

        vaultConfigurationModule.syncHarvestDelay(vault);

        assertEq(vault.harvestDelay(), 6 hours);
    }

    function testDefaultHarvestWindowOverridesCustomOfZero() public {
        // Harvest delay has to be set before harvest window.
        vaultConfigurationModule.setDefaultHarvestDelay(6 hours);
        vaultConfigurationModule.syncHarvestDelay(vault);

        vaultConfigurationModule.setDefaultHarvestWindow(5 minutes);

        vaultConfigurationModule.setVaultCustomHarvestWindow(vault, 0);

        vaultConfigurationModule.syncHarvestWindow(vault);

        assertEq(vault.harvestWindow(), 5 minutes);
    }

    function testDefaultTargetFloatPercentOverridesCustomOfZero() public {
        vaultConfigurationModule.setDefaultTargetFloatPercent(0.01e18);

        vaultConfigurationModule.setVaultCustomTargetFloatPercent(vault, 0);

        vaultConfigurationModule.syncTargetFloatPercent(vault);

        assertEq(vault.targetFloatPercent(), 0.01e18);
    }
}

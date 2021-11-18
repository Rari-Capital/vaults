// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

import {VaultConfigurationModule} from "./VaultConfigurationModule.sol";

/// @title Rari Vault Initialization Module
/// @author Transmissions11 and JetJadeja
/// @notice Module for initializing newly created Vaults.
contract VaultInitializationModule is Auth {
    /// @notice Vault configuration module used to configure Vaults before initialization.
    VaultConfigurationModule public configModule;

    /// @notice Creates a Vault initialization module.
    /// @param _configModule The Vault configuration module the
    /// module will use to configure Vaults before initialization.
    /// @param _owner The owner of the module.
    /// @param _authority The Authority of the module.
    constructor(
        VaultConfigurationModule _configModule,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) {
        configModule = _configModule;
    }

    /// @notice Emitted when the config module is updated.
    /// @param newConfigModule The new configuration module.
    event ConfigModuleUpdated(VaultConfigurationModule newConfigModule);

    /// @notice Sets a new Vault configuration module.
    /// @param newConfigModule The Vault configuration module to set.
    function setConfigModule(VaultConfigurationModule newConfigModule) external requiresAuth {
        // Update the config module.
        configModule = newConfigModule;

        emit ConfigModuleUpdated(newConfigModule);
    }

    /// @notice Properly configures and initializes a newly deployed Vault.
    /// @dev This will revert if the Vault has already been initialized.
    /// @param vault The Vault to configure and initialize.
    function initializeVault(Vault vault) external {
        // Configure all key parameters.
        configModule.syncFeePercent(vault);
        configModule.syncHarvestDelay(vault);
        configModule.syncHarvestWindow(vault);
        configModule.syncTargetFloatPercent(vault);

        // Open the Vault up for deposits.
        vault.initialize();
    }
}

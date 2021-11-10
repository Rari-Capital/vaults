// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

import {VaultConfigurationModule} from "./VaultConfigurationModule.sol";

/// @title Rari Vault Creation Module
/// @author Transmissions11 and JetJadeja
/// @notice Module for creating and configuring new Vaults.
contract VaultCreationModule is Auth {
    /// @notice The Vault factory instance to deploy with.
    VaultFactory public immutable FACTORY;

    /// @notice Vault configuration module instance to configure with.
    VaultConfigurationModule public configModule;

    /// @notice Creates a Vault creation module.
    /// @param _FACTORY The Vault factory instance the module should deploy with.
    /// @param _configModule The Vault configuration module the module should configure with.
    /// @param _owner The owner of the module.
    /// @param _authority The authority of the module.
    constructor(
        VaultFactory _FACTORY,
        VaultConfigurationModule _configModule,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) {
        FACTORY = _FACTORY;

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

    /// @notice Creates and properly configures a new Vault which supports a specific underlying token.
    /// @dev This will revert if a Vault that accepts the same underlying token has already been deployed.
    /// @param underlying The ERC20 token that the Vault should accept.
    /// @return vault The newly deployed Vault contract which accepts the provided underlying token.
    function createVault(ERC20 underlying) external returns (Vault vault) {
        // Deploy a new Vault with the underlying token.
        vault = FACTORY.deployVault(underlying);

        // Set all configuration parameters.
        configModule.syncFeePercent(vault);
        configModule.syncHarvestDelay(vault);
        configModule.syncHarvestWindow(vault);
        configModule.syncTargetFloatPercent(vault);

        // Open the Vault up for deposits.
        vault.initialize();
    }
}

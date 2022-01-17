// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "solmate/auth/Auth.sol";

import {Vault} from "../Vault.sol";

/// @title Rari Vault Configuration Module
/// @author Transmissions11 and JetJadeja
/// @notice Module for configuring Vault parameters.
contract VaultConfigurationModule is Auth {
    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a Vault configuration module.
    /// @param _owner The owner of the module.
    /// @param _authority The Authority of the module.
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    /*///////////////////////////////////////////////////////////////
                  DEFAULT VAULT PARAMETER CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the default fee percentage is updated.
    /// @param newDefaultFeePercent The new default fee percentage.
    event DefaultFeePercentUpdated(uint256 newDefaultFeePercent);

    /// @notice Emitted when the default harvest delay is updated.
    /// @param newDefaultHarvestDelay The new default harvest delay.
    event DefaultHarvestDelayUpdated(uint64 newDefaultHarvestDelay);

    /// @notice Emitted when the default harvest window is updated.
    /// @param newDefaultHarvestWindow The new default harvest window.
    event DefaultHarvestWindowUpdated(uint128 newDefaultHarvestWindow);

    /// @notice Emitted when the default target float percentage is updated.
    /// @param newDefaultTargetFloatPercent The new default target float percentage.
    event DefaultTargetFloatPercentUpdated(uint256 newDefaultTargetFloatPercent);

    /// @notice The default fee percentage for Vaults.
    /// @dev See the documentation for the feePercentage
    /// variable in the Vault contract for more details.
    uint256 public defaultFeePercent;

    /// @notice The default harvest delay for Vaults.
    /// @dev See the documentation for the harvestDelay
    /// variable in the Vault contract for more details.
    uint64 public defaultHarvestDelay;

    /// @notice The default harvest window for Vaults.
    /// @dev See the documentation for the harvestWindow
    /// variable in the Vault contract for more details.
    uint128 public defaultHarvestWindow;

    /// @notice The default target float percentage for Vaults.
    /// @dev See the documentation for the targetFloatPercent
    /// variable in the Vault contract for more details.
    uint256 public defaultTargetFloatPercent;

    /// @notice Sets the default fee percentage for Vaults.
    /// @param newDefaultFeePercent The new default fee percentage to set.
    function setDefaultFeePercent(uint256 newDefaultFeePercent) external requiresAuth {
        // Update the default fee percentage.
        defaultFeePercent = newDefaultFeePercent;

        emit DefaultFeePercentUpdated(newDefaultFeePercent);
    }

    /// @notice Sets the default harvest delay for Vaults.
    /// @param newDefaultHarvestDelay The new default harvest delay to set.
    function setDefaultHarvestDelay(uint64 newDefaultHarvestDelay) external requiresAuth {
        // Update the default harvest delay.
        defaultHarvestDelay = newDefaultHarvestDelay;

        emit DefaultHarvestDelayUpdated(newDefaultHarvestDelay);
    }

    /// @notice Sets the default harvest window for Vaults.
    /// @param newDefaultHarvestWindow The new default harvest window to set.
    function setDefaultHarvestWindow(uint128 newDefaultHarvestWindow) external requiresAuth {
        // Update the default harvest window.
        defaultHarvestWindow = newDefaultHarvestWindow;

        emit DefaultHarvestWindowUpdated(newDefaultHarvestWindow);
    }

    /// @notice Sets the default target float percentage for Vaults.
    /// @param newDefaultTargetFloatPercent The new default target float percentage to set.
    function setDefaultTargetFloatPercent(uint256 newDefaultTargetFloatPercent) external requiresAuth {
        // Update the default target float percentage.
        defaultTargetFloatPercent = newDefaultTargetFloatPercent;

        emit DefaultTargetFloatPercentUpdated(newDefaultTargetFloatPercent);
    }

    /*///////////////////////////////////////////////////////////////
                  CUSTOM VAULT PARAMETER CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a Vault has its custom fee percentage set/updated.
    /// @param vault The Vault that had its custom fee percentage set/updated.
    /// @param newCustomFeePercent The new custom fee percentage for the Vault.
    event CustomFeePercentUpdated(Vault indexed vault, uint256 newCustomFeePercent);

    /// @notice Emitted when a Vault has its custom harvest delay set/updated.
    /// @param vault The Vault that had its custom harvest delay set/updated.
    /// @param newCustomHarvestDelay The new custom harvest delay for the Vault.
    event CustomHarvestDelayUpdated(Vault indexed vault, uint256 newCustomHarvestDelay);

    /// @notice Emitted when a Vault has its custom harvest window set/updated.
    /// @param vault The Vault that had its custom harvest window set/updated.
    /// @param newCustomHarvestWindow The new custom harvest window for the Vault.
    event CustomHarvestWindowUpdated(Vault indexed vault, uint256 newCustomHarvestWindow);

    /// @notice Emitted when a Vault has its custom target float percentage set/updated.
    /// @param vault The Vault that had its custom target float percentage set/updated.
    /// @param newCustomTargetFloatPercent The new custom target float percentage for the Vault.
    event CustomTargetFloatPercentUpdated(Vault indexed vault, uint256 newCustomTargetFloatPercent);

    /// @notice Maps Vaults to their custom fee percentage.
    /// @dev Will be 0 if there is no custom fee percentage for the Vault.
    /// @dev See the documentation for the targetFloatPercent variable in the Vault contract for more details.
    mapping(Vault => uint256) public getVaultCustomFeePercent;

    /// @notice Maps Vaults to their custom harvest delay.
    /// @dev Will be 0 if there is no custom harvest delay for the Vault.
    /// @dev See the documentation for the harvestDelay variable in the Vault contract for more details.
    mapping(Vault => uint64) public getVaultCustomHarvestDelay;

    /// @notice Maps Vaults to their custom harvest window.
    /// @dev Will be 0 if there is no custom harvest window for the Vault.
    /// @dev See the documentation for the harvestWindow variable in the Vault contract for more details.
    mapping(Vault => uint128) public getVaultCustomHarvestWindow;

    /// @notice Maps Vaults to their custom target float percentage.
    /// @dev Will be 0 if there is no custom target float percentage for the Vault.
    /// @dev See the documentation for the targetFloatPercent variable in the Vault contract for more details.
    mapping(Vault => uint256) public getVaultCustomTargetFloatPercent;

    /// @notice Sets the custom fee percentage for the Vault.
    /// @param vault The Vault to set the custom fee percentage for.
    /// @param customFeePercent The new custom fee percentage to set.
    function setVaultCustomFeePercent(Vault vault, uint256 customFeePercent) external requiresAuth {
        // Update the Vault's custom fee percentage.
        getVaultCustomFeePercent[vault] = customFeePercent;

        emit CustomFeePercentUpdated(vault, customFeePercent);
    }

    /// @notice Sets the custom harvest delay for the Vault.
    /// @param vault The Vault to set the custom harvest delay for.
    /// @param customHarvestDelay The new custom harvest delay to set.
    function setVaultCustomHarvestDelay(Vault vault, uint64 customHarvestDelay) external requiresAuth {
        // Update the Vault's custom harvest delay.
        getVaultCustomHarvestDelay[vault] = customHarvestDelay;

        emit CustomHarvestDelayUpdated(vault, customHarvestDelay);
    }

    /// @notice Sets the custom harvest window for the Vault.
    /// @param vault The Vault to set the custom harvest window for.
    /// @param customHarvestWindow The new custom harvest window to set.
    function setVaultCustomHarvestWindow(Vault vault, uint128 customHarvestWindow) external requiresAuth {
        // Update the Vault's custom harvest window.
        getVaultCustomHarvestWindow[vault] = customHarvestWindow;

        emit CustomHarvestWindowUpdated(vault, customHarvestWindow);
    }

    /// @notice Sets the custom target float percentage for the Vault.
    /// @param vault The Vault to set the custom target float percentage for.
    /// @param customTargetFloatPercent The new custom target float percentage to set.
    function setVaultCustomTargetFloatPercent(Vault vault, uint256 customTargetFloatPercent) external requiresAuth {
        // Update the Vault's custom target float percentage.
        getVaultCustomTargetFloatPercent[vault] = customTargetFloatPercent;

        emit CustomTargetFloatPercentUpdated(vault, customTargetFloatPercent);
    }

    /*///////////////////////////////////////////////////////////////
                       VAULT PARAMETER SYNC LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Syncs a Vault's fee percentage with either the Vault's custom fee
    /// percentage or the default fee percentage if a custom percentage is not set.
    /// @param vault The Vault to sync the fee percentage for.
    function syncFeePercent(Vault vault) external {
        // Get the Vault's custom fee percentage.
        uint256 customFeePercent = getVaultCustomFeePercent[vault];

        // Determine what the new fee percentage should be for the Vault after the sync.
        uint256 newFeePercent = customFeePercent == 0 ? defaultFeePercent : customFeePercent;

        // Prevent spamming as this function requires no authorization.
        require(vault.feePercent() != newFeePercent, "ALREADY_SYNCED");

        // Set the Vault's fee percentage to the custom fee percentage
        // or the default fee percentage if a custom percentage isn't set.
        vault.setFeePercent(newFeePercent);
    }

    /// @notice Syncs a Vault's harvest delay with either the Vault's custom
    /// harvest delay or the default harvest delay if a custom delay is not set.
    /// @param vault The Vault to sync the harvest delay for.
    function syncHarvestDelay(Vault vault) external {
        // Get the Vault's custom harvest delay.
        uint64 customHarvestDelay = getVaultCustomHarvestDelay[vault];

        // Determine what the new harvest delay should be for the Vault after the sync.
        uint64 newHarvestDelay = customHarvestDelay == 0 ? defaultHarvestDelay : customHarvestDelay;

        // Prevent spamming as this function requires no authorization.
        require(vault.harvestDelay() != newHarvestDelay, "ALREADY_SYNCED");

        // Set the Vault's harvest delay to the custom harvest delay
        // or the default harvest delay if a custom delay isn't set.
        vault.setHarvestDelay(newHarvestDelay);
    }

    /// @notice Syncs a Vault's harvest window with either the Vault's custom
    /// harvest window or the default harvest window if a custom window is not set.
    /// @param vault The Vault to sync the harvest window for.
    function syncHarvestWindow(Vault vault) external {
        // Get the Vault's custom harvest window.
        uint128 customHarvestWindow = getVaultCustomHarvestWindow[vault];

        // Determine what the new harvest window should be for the Vault after the sync.
        uint128 newHarvestWindow = customHarvestWindow == 0 ? defaultHarvestWindow : customHarvestWindow;

        // Prevent spamming as this function requires no authorization.
        require(vault.harvestWindow() != newHarvestWindow, "ALREADY_SYNCED");

        // Set the Vault's harvest window to the custom harvest window
        // or the default harvest window if a custom window isn't set.
        vault.setHarvestWindow(newHarvestWindow);
    }

    /// @notice Syncs a Vault's target float percentage with either the Vault's custom target
    /// float percentage or the default target float percentage if a custom percentage is not set.
    /// @param vault The Vault to sync the target float percentage for.
    function syncTargetFloatPercent(Vault vault) external {
        // Get the Vault's custom target float percentage.
        uint256 customTargetFloatPercent = getVaultCustomTargetFloatPercent[vault];

        // Determine what the new target float percentage should be for the Vault after the sync.
        uint256 newTargetFloatPercent = customTargetFloatPercent == 0
            ? defaultTargetFloatPercent
            : customTargetFloatPercent;

        // Prevent spamming as this function requires no authorization.
        require(vault.targetFloatPercent() != newTargetFloatPercent, "ALREADY_SYNCED");

        // Set the Vault's target float percentage to the custom target float percentage
        // or the default target float percentage if a custom percentage isn't set.
        vault.setTargetFloatPercent(newTargetFloatPercent);
    }
}

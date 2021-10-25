// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {Vault} from "./Vault.sol";

/// @title Rari Vault Factory
/// @author Transmissions11 + JetJadeja
/// @notice Factory which enables deploying a Vault contract for any ERC20 token.
contract VaultFactory is Auth(msg.sender, Authority(address(0))) {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when `deployVault` is called.
    /// @param underlying The underlying token used in the vault.
    /// @param vault The new vault deployed that accepts the underlying token.
    event VaultDeployed(ERC20 underlying, Vault vault);

    /*///////////////////////////////////////////////////////////////
                          VAULT DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new Vault contract that supports a specific underlying asset.
    /// @dev This will revert if a vault with the token has already been created.
    /// @param underlying Address of the ERC20 token that the Vault will earn yield on.
    /// @return vault The newly deployed Vault contract.
    function deployVault(ERC20 underlying) external returns (Vault vault) {
        // Use the create2 opcode to deploy a Vault contract.
        // This will revert if a vault with this underlying has already been
        // deployed, as the salt would be the same and we can't deploy with it twice.
        vault = new Vault{salt: address(underlying).fillLast12Bytes()}(underlying);

        emit VaultDeployed(underlying, vault);
    }

    /*///////////////////////////////////////////////////////////////
                            VAULT LOOKUP LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a Vault's address from its underlying token.
    /// @dev The Vault returned may not have been deployed yet.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return The Vault that supports this underlying token.
    /// @dev The Vault returned may not be deployed yet. Use isVaultDeployed to check.
    function getVaultFromUnderlying(ERC20 underlying) external view returns (Vault) {
        return
            Vault(
                payable(
                    keccak256(
                        abi.encodePacked(
                            // Prefix:
                            bytes1(0xFF),
                            // Creator:
                            address(this),
                            // Salt:
                            address(underlying).fillLast12Bytes(),
                            // Bytecode hash:
                            keccak256(
                                abi.encodePacked(
                                    // Deployment bytecode:
                                    type(Vault).creationCode,
                                    // Constructor arguments:
                                    abi.encode(underlying)
                                )
                            )
                        )
                    ).fromLast20Bytes() // Convert the create hash into an address.
                )
            );
    }

    /// @notice Returns if a vault at an address has been deployed yet.
    /// @dev This function is useful to check the return value of
    /// getVaultFromUnderlying, as it may return vaults that have not been deployed yet.
    /// @param vault The address of the vault that may not have been deployed.
    /// @return A bool indicated whether the vault has been deployed already.
    function isVaultDeployed(Vault vault) external view returns (bool) {
        return address(vault).code.length > 0;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {Vault} from "./Vault.sol";

/// @title Fuse Vault Factory
/// @author Transmissions11 + JetJadeja
/// @notice Factory to deploy arbitrary Vault contracts to deterministic addresses.
contract VaultFactory {
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
                           STATEFUL FUNCTIONS
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
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a Vault's address from its underlying token.
    /// @dev The Vault returned may not have been deployed yet.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return The Vault that supports this underlying token.
    function getVaultFromUnderlying(ERC20 underlying) external view returns (Vault) {
        // Compute the create2 hash.
        bytes32 create2Hash = keccak256(
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
        );

        // Convert the create2 hash into a Vault address.
        return Vault(create2Hash.fromLast20Bytes());
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

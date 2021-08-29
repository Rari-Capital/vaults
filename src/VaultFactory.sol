// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

import {Vault} from "./Vault.sol";

/// @title VaultFactory
/// @author Transmissions11 + JetJadeja
/// @notice Factory contract, deploying proxy implementations.
contract VaultFactory {
    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful call to deploy.
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
    function deploy(ERC20 underlying, address feeClaimer) external returns (Vault vault) {
        // Generate a 32 byte salt for the create2 deployment.
        bytes32 salt = keccak256(abi.encode(underlying));

        // Use the create2 opcode to deploy the Vault contract.
        // This will revert if a vault with this underlying
        // has already been deployed, as the salt would be
        // the same and we can't deploy with it twice!
        vault = new Vault{salt: salt}(underlying);

        // Set the default fee claimer address
        vault.setFeeClaimer(feeClaimer);

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
        // Generate a bytecode hash.
        bytes memory bytecode = abi.encodePacked(type(Vault).creationCode, abi.encode(underlying));

        // Compute the create2 hash.
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), keccak256(abi.encode(underlying)), keccak256(bytecode))
        );

        // Turn the create2 hash into the vault address.
        return Vault(payable(address(uint160(uint256(hash)))));
    }

    /// @notice Returns if a vault at an address has been deployed yet.
    /// @dev This function is useful to check the return value of
    /// getVaultFromUnderlying, as it may return vaults that have not
    /// been deployed yet.
    /// @param vault The address of the vault that may not have been deployed.
    /// @return A bool indicated whether the vault has been deployed already.
    function isVaultDeployed(Vault vault) external view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(vault)
        }
        return size > 0;
    }
}

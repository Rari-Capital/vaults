// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./external/ERC20.sol";
import {Vault} from "./Vault.sol";

/// @title VaultFactory
/// @author TransmissionsDev + JetJadeja
/// @notice Factory contract, deploying proxy implementations.
contract VaultFactory {
    /// @notice Computes a Vault's address from its underlying token.
    /// @dev The Vault returned may not have been deployed yet.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return The Vault that supports this underlying token.
    function getVaultFromUnderlying(ERC20 underlying) public view returns (Vault) {
        bytes memory bytecode = abi.encodePacked(type(Vault).creationCode, abi.encode(underlying));

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), keccak256(abi.encode(underlying)), keccak256(bytecode))
        );

        return Vault(address(uint160(uint256(hash))));
    }

    /// @notice Deploy a new Vault contract.
    /// @notice This will revert if a vault with the token has already been created.
    /// @param underlying Address of the ERC20 token that the Vault will earn yield on.
    /// @return vault The newly deployed Vault contract.
    function deploy(ERC20 underlying) external returns (Vault vault) {
        // Generate a 32 byte salt for the create2 deployment.
        bytes32 salt = keccak256(abi.encode(underlying));
        // Use the create2 opcode to deploy the Vault contract.
        vault = new Vault{salt: salt}(underlying);
    }
}

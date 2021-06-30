// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./external/ERC20.sol";
import {Vault} from "./Vault.sol";

/// @title VaultFactory
/// @author TransmissionsDev + JetJadeja
/// @notice Factory contract, deploying proxy implementations.
contract VaultFactory {
    /// @notice Maps underlying ERC20s to a yield generating Vault (if it exists).
    mapping(ERC20 => Vault) public getVaultFromUnderlying;

    /// @notice Deploy a new Vault contract.
    /// @notice This will revert if a vault with the token has already been created.
    /// @param underlying Address of the ERC20 token that the Vault will earn yield on.
    /// @return vault The newly deployed Vault contract.
    function deploy(ERC20 underlying) external returns (Vault vault) {
        // Generate a 32 byte salt for the create2 deployment.
        bytes32 salt = keccak256(abi.encode(underlying));
        // Use the create2 opcode to deploy the Vault contract.
        vault = new Vault{salt: salt}(underlying);
        // Store the underlying's new vault address.
        getVaultFromUnderlying[underlying] = vault;
    }
}

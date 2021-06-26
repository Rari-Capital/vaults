// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

/* Contracts */
import {Vault} from "./Vault.sol";
import {ERC20} from "./external/ERC20.sol";

/**
    @title VaultFactory
    @author TransmissionsDev and JetJadeja
    @notice Factory contract, deploying proxy implementations
*/
contract VaultFactory {
    /**
        @dev Deploy a new Vault contract
        @param token Address of the ERC20 token that the Vault will earn yield on
        @return The Vault contract
    */
    function deploy(ERC20 token) external returns (Vault) {
        bytes32 salt = keccak256(abi.encode(token)); // Generate a 32 byte salt for the create2 deployment
        Vault vault = new Vault{salt: salt}(token); // Use the create2 opcode to deploy the Vault contract

        return vault; // If needed
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

/// @title Address/Bytes32 Conversion Library
/// @author Transmissions11
/// @notice Provides functions converting between bytes32 values and addresses.
library Bytes32AddressLib {
    /// @dev Converts a bytes32 value to an address.
    /// @param bytesValue The bytes value to convert to an address.
    /// @return The computed address.
    function toAddress(bytes32 bytesValue) internal pure returns (address) {
        return address(uint160(uint256(bytesValue)));
    }

    /// @dev Converts an address to a bytes32 value.
    /// @param account The address to convert to a bytes32 value.
    /// @return The computed bytes32 value.
    function toBytes32(address account) internal pure returns (bytes32) {
        return bytes32(bytes20(account));
    }
}

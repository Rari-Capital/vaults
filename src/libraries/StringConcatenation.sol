// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @title String concatenation library.
/// @author TransmissionsDev
/// @dev Uses abi.encodePacked, be aware of SWC-133.
library StringConcatenation {
    /// @notice Concatenates arg1, arg2, and arg3 in that order.
    function concat(
        string memory arg1,
        string memory arg2,
        string memory arg3
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(arg1, arg2, arg3));
    }

    /// @notice Concatenates arg1, arg2 in that order.
    function concat(string memory arg1, string memory arg2) internal pure returns (string memory) {
        return string(abi.encodePacked(arg1, arg2));
    }
}

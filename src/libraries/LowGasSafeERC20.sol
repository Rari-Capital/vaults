// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../external/ERC20.sol";

/// @title Low gas safe ERC20 interaction library.
/// @author TransmissionsDev
/// @dev Only supports safeTransfer and safeTransferFrom.
library LowGasSafeERC20 {
    /// @dev Safe wrapper around ERC20.transfer.
    /// @dev Reverts if the call reverts/returns false.
    function safeTransfer(
        ERC20 token,
        address to,
        uint256 value
    ) internal {
        erc20SafeCall(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /// @dev Safe wrapper around ERC20.transferFrom.
    /// @dev Reverts if the call reverts/returns false.
    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        erc20SafeCall(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /// @dev Calls an ERC20 with a custom payload and reverts if it returns false or reverts.
    /// @param token The token targeted by the call.
    /// @param data The call data (generated using abi.encode or one of its variants).
    function erc20SafeCall(ERC20 token, bytes memory data) internal {
        // We don't check that the contract has code because the vault already checks on deployment.
        (bool success, bytes memory returnData) = address(token).call(data);

        if (success) {
            // Return data is optional, but it returned it needs to be a positive bool.
            if (returnData.length > 0) {
                require(abi.decode(returnData, (bool)), "ERC20_CALL_FAIL");
            }
        } else {
            // If the call didn't give a revert reason, revert right now.
            require(returnData.length > 0, "ERC20_CALL_REVERT");

            // Bubble up the revert reason if present.
            assembly {
                let returnDataSize := mload(returnData)
                revert(add(32, returnData), returnDataSize)
            }
        }
    }
}

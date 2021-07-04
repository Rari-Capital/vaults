// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

library SafeERC20 {
    function safeTransfer(
        ERC20 token,
        address to,
        uint256 value
    ) internal {
        bytes memory returndata = functionCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );

        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        bytes memory returndata = functionCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );

        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    // TODO: Optimize: remove this function and inline it into the above? would that save bytes copy gas?
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        require(size > 0, "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call(data);

        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("low-level call failed");
            }
        }
    }
}

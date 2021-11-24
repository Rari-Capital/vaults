// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @notice Minimal interface for tokens using DAI's non-standard permit interface.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/external/IERC20PermitAllowed.sol)
abstract contract AllowedPermit is ERC20 {
    /// @param holder The address of the token owner.
    /// @param spender The address of the token spender.
    /// @param nonce The owner's nonce, increases at each call to permit.
    /// @param expiry The timestamp at which the permit is no longer valid.
    /// @param allowed Boolean that sets approval amount, true for type(uint256).max and false for 0.
    /// @param v Must produce valid secp256k1 signature from the owner along with r and s.
    /// @param r Must produce valid secp256k1 signature from the owner along with v and s.
    /// @param s Must produce valid secp256k1 signature from the owner along with r and v.
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual;
}

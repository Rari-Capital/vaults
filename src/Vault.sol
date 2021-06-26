// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./external/ERC20.sol";
import "./libraries/StringConcat.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset for fvTokens to instantly begin earning yield.
contract Vault is ERC20 {
    /// @notice The underlying token for the vault.
    ERC20 public immutable underlying;

    /// @notice Creates a new vault based on an underlying token.
    /// @param _underlying An underlying ERC20 compliant token.
    constructor(ERC20 _underlying)
        ERC20(
            // ex: Fuse DAI Vault
            StringConcat.concat("Fuse ", _underlying.name(), " Vault"),
            // fvDAI
            StringConcat.concat("fv", _underlying.symbol())
        )
    {
        underlying = _underlying;
    }

    /// @notice Deposits an underlying token and mints fvTokens.
    /// @param amount The amount of the underlying token to deposit.
    function deposit(uint256 amount) external {
        _mint(msg.sender, amount);

        // Transfer in underlying tokens from the sender.
        underlying.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the sender.
    /// @param amount The amount of fvTokens to burn.
    function withdraw(uint256 amount) external {
        // This will revert if the user does not have enough fvTokens.
        _burn(msg.sender, amount);

        // Transfer underlying tokens to the sender.
        underlying.transfer(msg.sender, amount);
    }
}

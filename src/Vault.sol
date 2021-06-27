// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DSAuth} from "ds-auth/auth.sol";
import {ERC20} from "./external/ERC20.sol";
import {StringConcat} from "./libraries/StringConcat.sol";

/// @title Fuse Vault/fvToken
/// @author TransmissionsDev + JetJadeja
/// @notice Yield bearing token that enables users to swap their
/// underlying asset for fvTokens to instantly begin earning yield.
contract Vault is ERC20, DSAuth {
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
    function deposit(uint256 amount) external auth {
        // Transfer in underlying tokens from the sender.
        underlying.transferFrom(msg.sender, address(this), amount);

        // Get the token exchangeRate and underlying decimals
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 decimals = underlying.decimals();

        _mint(msg.sender, (exchangeRate * amount) / 10**decimals);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the sender.
    /// @param amount The amount of fvTokens to burn.
    function withdraw(uint256 amount) external auth {
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 decimals = underlying.decimals();
        _burn(msg.sender, (amount * 1e36) / (10**decimals / exchangeRate));

        // Transfer underlying tokens to the sender.
        underlying.transfer(msg.sender, amount);
    }

    /// @notice Returns the current fvToken exchange rate, scaled by 1e18.
    function exchangeRateCurrent() public view returns (uint256) {
        // Total fvToken supply and vault's total balance in underlying tokens.
        uint256 supply = totalSupply();
        uint256 balance = totalUnderlying();
        // If either the supply or balance is 0, return 1.
        if (supply == 0 || balance == 0) return 1e18;

        uint256 decimals = underlying.decimals();
        return (balance * 1e36) / (10**decimals * supply);
    }

    /// @return Returns total underlying balance.
    function totalUnderlying() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }
}

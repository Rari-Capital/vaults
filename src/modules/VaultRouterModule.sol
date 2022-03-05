// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {AllowedPermit} from "../interfaces/AllowedPermit.sol";

import {Vault} from "../Vault.sol";

/// @title Rari Vault Router Module
/// @author Transmissions11 and JetJadeja
/// @notice Module that enables depositing ETH into WETH compatible Vaults
/// and approval-free deposits into Vaults with permit compatible underlying.
contract VaultRouterModule {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                              DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit ETH into a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to deposit into.
    function depositETHIntoVault(Vault vault) external payable {
        // Ensure the Vault's underlying is stored as WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(payable(address(vault.UNDERLYING())));

        // Wrap the ETH into WETH.
        weth.deposit{value: msg.value}();

        // Deposit and transfer the minted rvTokens back to the caller.
        depositIntoVaultForCaller(vault, weth, msg.value);
    }

    /// @notice Deposits into a Vault, transferring in its underlying token from the caller via permit.
    /// @param vault The Vault to deposit into.
    /// @param underlyingAmount The amount of underlying tokens to deposit into the Vault.
    /// @param deadline A timestamp, the block's timestamp must be less than or equal to this timestamp.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    /// @dev Use depositIntoVaultWithAllowedPermit for tokens using DAI's non-standard permit interface.
    function depositIntoVaultWithPermit(
        Vault vault,
        uint256 underlyingAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Get the Vault's underlying token.
        ERC20 underlying = vault.UNDERLYING();

        // Transfer in the provided amount of underlying tokens from the caller via permit.
        permitAndTransferFromCaller(underlying, underlyingAmount, deadline, v, r, s);

        // Deposit and transfer the minted rvTokens back to the caller.
        depositIntoVaultForCaller(vault, underlying, underlyingAmount);
    }

    /// @notice Deposits into a Vault, transferring in its underlying token from the caller via allowed permit.
    /// @param vault The Vault to deposit into.
    /// @param underlyingAmount The amount of underlying tokens to deposit into the Vault.
    /// @param nonce The callers's nonce, increases at each call to permit.
    /// @param expiry The timestamp at which the permit is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    /// @dev Alternative to depositIntoVaultWithPermit for tokens using DAI's non-standard permit interface.
    function depositIntoVaultWithAllowedPermit(
        Vault vault,
        uint256 underlyingAmount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Get the Vault's underlying token.
        ERC20 underlying = vault.UNDERLYING();

        // Transfer in the provided amount of underlying tokens from the caller via allowed permit.
        allowedPermitAndTransferFromCaller(underlying, underlyingAmount, nonce, expiry, v, r, s);

        // Deposit and transfer the minted rvTokens back to the caller.
        depositIntoVaultForCaller(vault, underlying, underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                            WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to withdraw from.
    /// @param underlyingAmount The amount of ETH to withdraw from the Vault.
    function withdrawETHFromVault(Vault vault, uint256 underlyingAmount) external {
        // Ensure the Vault's underlying is stored as WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Compute the amount of rvTokens equivalent to the underlying amount.
        // We know the Vault's base unit is 1e18 as it's required for underlyingIsWETH to be true.
        uint256 rvTokenAmount = underlyingAmount.divWadDown(vault.exchangeRate());

        // Transfer in the equivalent amount of rvTokens from the caller.
        ERC20(vault).safeTransferFrom(msg.sender, address(this), rvTokenAmount);

        // Withdraw from the Vault.
        vault.withdraw(underlyingAmount);

        // Unwrap the withdrawn amount of WETH and transfer it to the caller.
        unwrapAndTransfer(WETH(payable(address(vault.UNDERLYING()))), underlyingAmount);
    }

    /// @notice Withdraw ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to withdraw from.
    /// @param underlyingAmount The amount of ETH to withdraw from the Vault.
    /// @param deadline A timestamp, the block's timestamp must be less than or equal to this timestamp.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    function withdrawETHFromVaultWithPermit(
        Vault vault,
        uint256 underlyingAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Ensure the Vault's underlying is stored as WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Compute the amount of rvTokens equivalent to the underlying amount.
        // We know the Vault's base unit is 1e18 as it's required for underlyingIsWETH to be true.
        uint256 rvTokenAmount = underlyingAmount.divWadDown(vault.exchangeRate());

        // Transfer in the equivalent amount of rvTokens from the caller via permit.
        permitAndTransferFromCaller(vault, rvTokenAmount, deadline, v, r, s);

        // Withdraw from the Vault.
        vault.withdraw(underlyingAmount);

        // Unwrap the withdrawn amount of WETH and transfer it to the caller.
        unwrapAndTransfer(WETH(payable(address(vault.UNDERLYING()))), underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                              REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Redeem ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to redeem from.
    /// @param rvTokenAmount The amount of rvTokens to withdraw from the Vault.
    function redeemETHFromVault(Vault vault, uint256 rvTokenAmount) external {
        // Ensure the Vault's underlying is stored as WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Transfer in the provided amount of rvTokens from the caller.
        ERC20(vault).safeTransferFrom(msg.sender, address(this), rvTokenAmount);

        // Redeem the rvTokens.
        vault.redeem(rvTokenAmount);

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(payable(address(vault.UNDERLYING())));

        // Unwrap all our WETH and transfer it to the caller.
        unwrapAndTransfer(weth, weth.balanceOf(address(this)));
    }

    /// @notice Redeem ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to redeem from.
    /// @param rvTokenAmount The amount of rvTokens to withdraw from the Vault.
    /// @param deadline A timestamp, the block's timestamp must be less than or equal to this timestamp.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    function redeemETHFromVaultWithPermit(
        Vault vault,
        uint256 rvTokenAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Ensure the Vault's underlying is stored as WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Transfer in the provided amount of rvTokens from the caller via permit.
        permitAndTransferFromCaller(vault, rvTokenAmount, deadline, v, r, s);

        // Redeem the rvTokens.
        vault.redeem(rvTokenAmount);

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(payable(address(vault.UNDERLYING())));

        // Unwrap all our WETH and transfer it to the caller.
        unwrapAndTransfer(weth, weth.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////
                          WETH UNWRAPPING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Unwraps the provided amount of WETH and transfers it to the caller.
    /// @param weth The WETH contract to withdraw the amount from.
    /// @param amount The amount of WETH to unwrap into ETH and transfer.
    function unwrapAndTransfer(WETH weth, uint256 amount) internal {
        // Convert the WETH into ETH.
        weth.withdraw(amount);

        // Transfer the unwrapped ETH to the caller.
        msg.sender.safeTransferETH(amount);
    }

    /*///////////////////////////////////////////////////////////////
                          VAULT DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Approves tokens, deposits them into a Vault
    /// and transfers the minted rvTokens back to the caller.
    /// @param vault The Vault to deposit into.
    /// @param underlying The underlying token the Vault accepts.
    /// @param amount The minimum amount that must be approved.
    function depositIntoVaultForCaller(
        Vault vault,
        ERC20 underlying,
        uint256 amount
    ) internal {
        // Approve the underlying tokens to the Vault.
        underlying.safeApprove(address(vault), amount);

        // Deposit the underlying tokens into the Vault.
        vault.deposit(amount);

        // Transfer the newly minted rvTokens back to the caller.
        ERC20(vault).safeTransfer(msg.sender, vault.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Permits tokens from the caller and transfers them into the module.
    /// @param token The token to permit and transfer in.
    /// @param amount The amount of tokens to permit and transfer in.
    /// @param deadline A timestamp, the block's timestamp must be less than or equal to this timestamp.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    function permitAndTransferFromCaller(
        ERC20 token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        // Approve the tokens from the caller to the module via permit.
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // Transfer the tokens from the caller to the module.
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev Max permits tokens from the caller and transfers them into the module.
    /// @param token The token to permit and transfer in.
    /// @param amount The amount of tokens to permit and transfer in.
    /// @param nonce The callers's nonce, increases at each call to permit.
    /// @param expiry The timestamp at which the permit is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the caller along with r and s.
    /// @param r Must produce valid secp256k1 signature from the caller along with v and s.
    /// @param s Must produce valid secp256k1 signature from the caller along with r and v.
    /// @dev Alternative to permitAndTransferFromCaller for tokens using DAI's non-standard permit interface.
    function allowedPermitAndTransferFromCaller(
        ERC20 token,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        // Approve the tokens from the caller to the module via DAI's non-standard permit.
        AllowedPermit(address(token)).permit(msg.sender, address(this), nonce, expiry, true, v, r, s);

        // Transfer the tokens from the caller to the module.
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the module to receive unwrapped ETH.
    receive() external payable {}
}

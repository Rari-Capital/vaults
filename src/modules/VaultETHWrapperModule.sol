// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {WETH} from "../interfaces/WETH.sol";

import {Vault} from "../Vault.sol";

/// @title Vault ETH Wrapper Module
/// @author Transmissions11 + JetJadeja
/// @notice Wrapper for using ETH with a WETH Vault.
contract VaultETHWrapperModule {
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    /// @notice Deposit ETH into a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to deposit into.
    /// @dev The caller must attach the amount they want to deposit as msg.value.
    function depositETHIntoVault(Vault vault) external payable {
        // Ensure the Vault's underlying token is WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(address(vault.UNDERLYING()));

        // Wrap the ETH into WETH.
        weth.deposit{value: msg.value}();

        // Approve the WETH to the Vault.
        weth.approve(address(vault), msg.value);

        // Deposit the WETH into the Vault.
        vault.deposit(msg.value);

        // Get the Vault's rvToken.
        ERC20 rvToken = ERC20(vault);

        // Transfer the newly minted rvTokens back to the user.
        rvToken.transfer(msg.sender, rvToken.balanceOf(address(this)));
    }

    /// @notice Withdraw ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to withdraw from.
    /// @param underlyingAmount The amount of ETH to withdraw from the Vault.
    /// @dev The caller must approve the equivalent amount of rvTokens to the module.
    function withdrawETHFromVault(Vault vault, uint256 underlyingAmount) external {
        // Ensure the Vault's underlying token is WETH compatible.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Compute the amount of rvTokens equivalent to the underlying amount.
        // We know the Vault's base unit is 1e18 as it's required if underlyingIsWETH returns true.
        uint256 rvTokenAmount = underlyingAmount.fdiv(vault.exchangeRate(), 1e18);

        // Get the Vault's rvToken.
        ERC20 rvToken = ERC20(vault);

        // Transfer in the equivalent amount of rvTokens from the caller.
        rvToken.safeTransferFrom(msg.sender, address(this), rvTokenAmount);

        // Withdraw from the Vault.
        vault.withdraw(underlyingAmount);

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(address(vault.UNDERLYING()));

        // Convert the WETH into ETH.
        weth.withdraw(underlyingAmount);

        // Transfer the unwrapped ETH to the caller.
        SafeERC20.safeTransferETH(msg.sender, underlyingAmount);
    }

    /// @notice Redeem ETH from a WETH compatible Vault.
    /// @param vault The WETH compatible Vault to redeem from.
    /// @param rvTokenAmount The amount of rvTokens to withdraw from the Vault.
    /// @dev The caller must approve the provided amount of rvTokens to the module.
    function redeemETHFromVault(Vault vault, uint256 rvTokenAmount) external {
        // Ensure the Vault accepts WETH.
        require(vault.underlyingIsWETH(), "UNDERLYING_NOT_WETH");

        // Get the Vault's rvToken.
        ERC20 rvToken = ERC20(vault);

        // Transfer in the rvTokens from the caller.
        rvToken.safeTransferFrom(msg.sender, address(this), rvTokenAmount);

        // Redeem the rvTokens.
        vault.redeem(rvTokenAmount);

        // Get the Vault's underlying as WETH.
        WETH weth = WETH(address(vault.UNDERLYING()));

        // Get how much WETH we redeemed.
        uint256 withdrawnWETH = weth.balanceOf(address(this));

        // Convert the WETH into ETH.
        weth.withdraw(withdrawnWETH);

        // Transfer the unwrapped ETH to the caller.
        SafeERC20.safeTransferETH(msg.sender, withdrawnWETH);
    }

    /// @dev Required for the module to receive unwrapped ETH.
    receive() external payable {}
}

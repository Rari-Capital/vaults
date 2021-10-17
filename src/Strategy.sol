// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";

/// @title Rari Vault Strategy
/// @author Transmissions11 + JetJadeja
/// @notice Minimalist strategy interface.
interface Strategy {
    /// @dev If reverts, the Vault will assume false.
    function isCEther() external view returns (bool);

    /// @dev Only need to implement if isCEther returns false.
    function underlying() external view returns (ERC20);

    /// @dev Only need to implement if isCEther returns true.
    function mint() external payable;

    // TODO: Don't require these to return bools just handle them like safeerc20.

    /// @dev Only need to implement if isCEther returns false.
    function mint(uint256) external returns (uint256);

    function balanceOfUnderlying(address) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);
}

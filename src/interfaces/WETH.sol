// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";

/// @title WETH
/// @notice Minimal interface for Wrapped Ether.
abstract contract WETH is ERC20 {
    function deposit() external payable virtual;

    function withdraw(uint256) external virtual;
}

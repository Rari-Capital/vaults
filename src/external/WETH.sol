// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

interface WETH {
    function deposit() external payable;

    function withdraw(uint256) external;

    function transfer(address, uint256) external;
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

interface Strategy {
    function underlying() external view returns (ERC20);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    // TODO: Ether support
    // function mint() external payable returns (uint256);
    // function isCEther() external view returns (bool);
}

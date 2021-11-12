// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

abstract contract Strategy is ERC20 {
    function isCEther() external view virtual returns (bool);

    function redeemUnderlying(uint256 amount) external virtual returns (uint256);

    function balanceOfUnderlying(address user) external virtual returns (uint256);
}

abstract contract ERC20Strategy is Strategy {
    function underlying() external view virtual returns (ERC20);

    function mint(uint256 amount) external virtual returns (uint256);
}

abstract contract ETHStrategy is Strategy {
    function mint() external payable virtual;
}

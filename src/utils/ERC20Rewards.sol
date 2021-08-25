pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

contract ERC20Rewards is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {}
}

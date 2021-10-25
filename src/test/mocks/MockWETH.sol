// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

import {WETH} from "../../interfaces/WETH.sol";

contract MockWETH is ERC20("Mock Wrapped Ether", "MWETH", 18), WETH {
    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    function deposit() public payable override {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _burn(msg.sender, amount);

        SafeERC20.safeTransferETH(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    receive() external payable {
        deposit();
    }
}

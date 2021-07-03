// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../external/ERC20.sol";

contract MockERC20 is ERC20("Mock Token", "MOCK") {
    function mintIfNeeded(address guy, uint256 amount) external {
        uint256 currentBal = balanceOf(guy);
        // If the guy does not have enough to cover this amount:
        if (amount > currentBal) {
            // Mint enough to reach amount.
            _mint(guy, amount - currentBal);
        }
    }
}

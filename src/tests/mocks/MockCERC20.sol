// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "../../external/ERC20.sol";

contract MockCERC20 is ERC20("Mock Token", "MOCK", 18) {
    ERC20 underlying;

    constructor(ERC20 _underlying) {
        underlying = _underlying;
    }

    function mint(uint256 amount) external returns (uint256) {
        // Transfer underlying tokens to the cToken.
        underlying.transferFrom(msg.sender, address(this), amount);
        // Mint cTokens.
        _mint(msg.sender, amount);

        return amount;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        underlying.transfer(msg.sender, redeemTokens);

        _burn(msg.sender, redeemTokens);
    }

    function balanceOfUnderlying() external view returns (uint256) {
        return underlying.balanceOf(address(this));
    }
}

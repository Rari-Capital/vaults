// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "../../external/ERC20.sol";

contract MockCERC20 is ERC20("Mock CERC20", "MCERC20", 18) {
    ERC20 immutable underlying;

    constructor(ERC20 _underlying) {
        underlying = _underlying;
    }

    function mint(uint256 amount) external returns (uint256) {
        underlying.transferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);

        // TODO: We should prolly return actual error codes and not revert as per CERC20 spec
        return 0;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        underlying.transfer(msg.sender, redeemTokens);
        _burn(msg.sender, redeemTokens);

        return 0;
    }

    function balanceOfUnderlying(address account) external view returns (uint256) {
        return underlying.balanceOf(account);
    }
}

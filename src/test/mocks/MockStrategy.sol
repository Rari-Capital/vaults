// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20Strategy} from "../../interfaces/Strategy.sol";

contract MockStrategy is ERC20Strategy {
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                           STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(ERC20 _UNDERLYING) ERC20("Mock Strategy", "vsMOCK", 18) {
        UNDERLYING = _UNDERLYING;

        BASE_UNIT = 10**_UNDERLYING.decimals();
    }

    function isCEther() external pure override returns (bool) {
        return false;
    }

    function underlying() external view override returns (ERC20) {
        return UNDERLYING;
    }

    function mint(uint256 underlyingAmount) external override returns (uint256) {
        // Convert UNDERLYING tokens to cTokens and mint them.
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        // Transfer in UNDERLYING tokens from the sender.
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        return 0;
    }

    function redeemUnderlying(uint256 underlyingAmount) external override returns (uint256) {
        // Convert UNDERLYING tokens to cTokens and then burn them.
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        // Transfer UNDERLYING tokens to the caller.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);

        return 0;
    }

    function balanceOfUnderlying(address account) external view override returns (uint256) {
        return balanceOf[account].fmul(exchangeRate(), BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    ERC20 internal immutable UNDERLYING;

    uint256 internal immutable BASE_UNIT;

    function exchangeRate() internal view returns (uint256) {
        // If there are no cTokens in circulation, return an exchange rate of 1:1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        return UNDERLYING.balanceOf(address(this)).fdiv(totalSupply, BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function simulateLoss(uint256 underlyingAmount) external {
        UNDERLYING.safeTransfer(0x000000000000000000000000000000000000dEaD, underlyingAmount);
    }
}

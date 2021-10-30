// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20Strategy} from "../../interfaces/Strategy.sol";

contract MockStrategy is ERC20("Mock cToken Strategy", "cMOCK", 18), ERC20Strategy {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                           STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(ERC20 _UNDERLYING) {
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
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        return 0;
    }

    function redeemUnderlying(uint256 underlyingAmount) external override returns (uint256) {
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);

        return 0;
    }

    function balanceOfUnderlying(address user) external view override returns (uint256) {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    ERC20 internal immutable UNDERLYING;

    uint256 internal immutable BASE_UNIT;

    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        return UNDERLYING.balanceOf(address(this)).fdiv(cTokenSupply, BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function simulateLoss(uint256 underlyingAmount) external {
        UNDERLYING.safeTransfer(address(0xDEAD), underlyingAmount);
    }
}

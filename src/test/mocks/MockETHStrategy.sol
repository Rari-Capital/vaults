// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ETHStrategy} from "../../interfaces/Strategy.sol";

contract MockETHStrategy is ERC20("Mock cEther Strategy", "cEther", 18), ETHStrategy {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                             STRATEGY LOGIC
    //////////////////////////////////////////////////////////////*/

    function isCEther() external pure override returns (bool) {
        return true;
    }

    function mint() external payable override {
        _mint(msg.sender, msg.value.divWadDown(exchangeRate()));
    }

    function redeemUnderlying(uint256 amount) external override returns (uint256) {
        _burn(msg.sender, amount.divWadDown(exchangeRate()));

        msg.sender.safeTransferETH(amount);

        return 0;
    }

    function balanceOfUnderlying(address user) external view override returns (uint256) {
        return balanceOf[user].mulDivDown(exchangeRate(), 1e18);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return 1e18;

        return address(this).balance.divWadDown(cTokenSupply);
    }

    /*///////////////////////////////////////////////////////////////
                              MOCK LOGIC
    //////////////////////////////////////////////////////////////*/

    function simulateLoss(uint256 underlyingAmount) external {
        address(0xDEAD).safeTransferETH(underlyingAmount);
    }
}

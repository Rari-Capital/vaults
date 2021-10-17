// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

import {Strategy} from "./Strategy.sol";
import {WETH9} from "./external/WETH9.sol";

/// @title Rari Vault Strategy Library
/// @author Transmissions11 + JetJadeja
/// @notice Library for safely interacting with strategies.
library StrategyLib {
    using SafeERC20 for ERC20;

    // TODO: some sort of system for determining if weth9
    WETH9 constant weth9 = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function takesETH(Strategy strategy) internal view returns (bool) {
        // TODO: is this cheaper than try catch? is a call cheaper than staticcall?
        (bool success, bytes memory returnData) = address(strategy).staticcall(
            // TODO: Make this a constant or hardcode hash to save opcodes?
            abi.encodeWithSelector(strategy.isCEther.selector)
        );

        return success ? abi.decode(returnData, (bool)) : false;
    }

    function deposit(Strategy strategy, uint256 underlyingAmount) internal {
        if (takesETH(strategy)) {
            // Unwrap the right amount of WETH.
            weth9.withdraw(underlyingAmount);

            // Deposit into the strategy and assume it will revert on error.
            strategy.mint{value: underlyingAmount}();
        } else {
            // TODO: Just take this as an arg?
            ERC20 underlying = strategy.underlying();

            // Approve underlyingAmount to the strategy so we can deposit.
            underlying.safeApprove(address(strategy), underlyingAmount);

            // Deposit into the strategy and revert if it returns an error code.
            require(strategy.mint(underlyingAmount) == 0, "MINT_FAILED");
        }
    }

    function withdraw(Strategy strategy, uint256 underlyingAmount) internal {
        // Withdraw from the strategy and revert if returns an error code.
        require(strategy.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");

        // Wrap the withdrawn Ether into WETH if necessary.
        if (takesETH(strategy)) weth9.deposit{value: underlyingAmount}();
    }
}

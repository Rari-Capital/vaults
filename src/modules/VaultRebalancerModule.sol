pragma solidity 0.8.10;

import {Strategy} from "../interfaces/Strategy.sol";
import {Vault} from "../Vault.sol";

/// @title Vault Rebalancer Module
/// @author Transmissions11 and JetJadeja
/// @notice Module that automatically rebalances the Vault
contract VaultRebalancerModule {
    struct Alloc {
        Strategy strategy;
        uint256 amount;
    }

    function rebalance(
        Vault vault,
        Alloc[] memory strategiesToWithdrawFrom,
        Alloc[] memory strategiesToDepositInto
    ) external {
        uint256 totalWithdraw;
        uint256 totalDeposit;
        uint256 vaultBaseUnit = vault.BASE_UNIT();

        for (uint256 i = 0; i < strategiesToWithdrawFrom.length; i++) {
            totalWithdraw += strategiesToWithdrawFrom[i].amount;
            vault.withdrawFromStrategy(strategiesToWithdrawFrom[i].strategy, strategiesToWithdrawFrom[i].amount);
        }

        uint256 interestInWithdrawalPools = calculateWeightedAverage(
            strategiesToWithdrawFrom,
            totalWithdraw,
            vaultBaseUnit
        );

        for (uint256 i = 0; i < strategiesToWithdrawFrom.length; i++) {
            totalDeposit += strategiesToDepositInto[i].amount;
            vault.withdrawFromStrategy(strategiesToDepositInto[i].strategy, strategiesToDepositInto[i].amount);
        }

        uint256 interestInDepositPools = calculateWeightedAverage(strategiesToDepositInto, totalDeposit, vaultBaseUnit);

        require(interestInWithdrawalPools < interestInDepositPools, "");
    }

    function calculateWeightedAverage(
        Alloc[] memory strategies,
        uint256 total,
        uint256 baseUnit
    ) internal returns (uint256) {
        uint256 weightedTotal;
        uint256 sumOfWeights;

        for (uint256 i = 0; i < strategies.length; i++) {
            // Weight of the strategy, scaled by 10^decimals.
            uint256 weight = (strategies[i].amount * baseUnit) / total;

            // Add to the sum of the weights.
            sumOfWeights += weight;

            // Add to the weighted total amount.
            weightedTotal += weight * strategies[i].strategy.supplyRatePerBlock();
        }

        // Divide the weighted total by the number of strategies.
        return weightedTotal / sumOfWeights;
    }
}

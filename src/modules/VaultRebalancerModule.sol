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
        for (uint256 i = 0; i < strategiesToWithdrawFrom.length; i++) {
            vault.withdrawFromStrategy(strategiesToWithdrawFrom[i].strategy, strategiesToWithdrawFrom[i].amount);
        }

        for (uint256 i = 0; i < strategiesToWithdrawFrom.length; i++) {
            vault.withdrawFromStrategy(strategiesToDepositInto[i].strategy, strategiesToDepositInto[i].amount);
        }
    }
}

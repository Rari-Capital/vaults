pragma solidity 0.8.10;

import {Strategy} from "../interfaces/Strategy.sol";
import {Vault} from "../Vault.sol";

/// @title Vault Rebalancer Module
/// @author Transmissions11 and JetJadeja
/// @notice Module that automatically rebalances the Vault
contract VaultRebalancerModule {
    function rebalance(
        Vault vault,
        Strategy withdrawalContract,
        Strategy depositContract,
        uint256 amount
    ) external {
        vault.withdrawFromStrategy(withdrawalContract, amount);
        vault.depositIntoStrategy(depositContract, amount);

        require(depositContract.supplyRatePerBlock() > withdrawalContract.supplyRatePerBlock(), "SUPPLY_RATE_TOO_LOW");
    }
}

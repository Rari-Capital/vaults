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
        uint256 shareOfVault = (amount * vault.BASE_UNIT()) / vault.totalHoldings();

        require(shareOfVault < ((3 * vault.totalHoldings()) / 20));

        uint256 withdrawalSupplyRate = withdrawalContract.supplyRatePerBlock();

        vault.withdrawFromStrategy(withdrawalContract, amount);
        vault.depositIntoStrategy(depositContract, amount);

        require(depositContract.supplyRatePerBlock() > withdrawalSupplyRate, "RATE_MUST_INCREASE");
    }
}

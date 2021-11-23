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
        // Calculate what percentage of the Vault's totalHoldings are being transfered
        uint256 shareOfVault = (amount * vault.BASE_UNIT()) / vault.totalHoldings();

        // Ensure that less than 15% of the Vault is being transferred.
        require(shareOfVault < ((3 * vault.totalHoldings()) / 20));

        // Store the supply rate of the strategy being withdrew from.
        uint256 withdrawalSupplyRate = withdrawalContract.supplyRatePerBlock();

        // Transfer the tokens
        vault.withdrawFromStrategy(withdrawalContract, amount);
        vault.depositIntoStrategy(depositContract, amount);

        // Ensure that the supply rate of the new strategy is larger than the supply rate of the old strategy
        require(depositContract.supplyRatePerBlock() > withdrawalSupplyRate, "RATE_MUST_INCREASE");
    }
}

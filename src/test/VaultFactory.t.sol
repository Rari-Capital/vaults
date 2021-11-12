// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultFactoryTest is DSTestPlus {
    VaultFactory vaultFactory;

    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vaultFactory = new VaultFactory(address(this), Authority(address(0)));
    }

    function testDeployVault() public {
        Vault vault = vaultFactory.deployVault(underlying);
        assertTrue(vaultFactory.isVaultDeployed(vault));

        assertEq(address(vaultFactory.getVaultFromUnderlying(underlying)), address(vault));
        assertEq(address(vault.UNDERLYING()), address(underlying));

        assertFalse(vault.isInitialized());

        assertEq(vault.feePercent(), 0);
        assertEq(vault.harvestDelay(), 0);
        assertEq(vault.harvestWindow(), 0);
        assertEq(vault.targetFloatPercent(), 0);
    }

    function testFailNoDuplicateVaults() public {
        vaultFactory.deployVault(underlying);
        vaultFactory.deployVault(underlying);
    }
}

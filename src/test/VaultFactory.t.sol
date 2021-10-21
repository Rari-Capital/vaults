// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultFactoryTest is DSTestPlus {
    VaultFactory vaultFactory;
    MockERC20 underlying;

    function setUp() public {
        vaultFactory = new VaultFactory();
        underlying = new MockERC20("Mock Token", "TKN", 18);
    }

    function testDeployVault() public {
        Vault vault = vaultFactory.deployVault(underlying);
        assertTrue(vaultFactory.isVaultDeployed(vault));

        assertVaultEq(vaultFactory.getVaultFromUnderlying(underlying), vault);
        assertERC20Eq(vault.UNDERLYING(), underlying);
    }

    function testFailNoDuplicateVaults() public {
        vaultFactory.deployVault(underlying);
        vaultFactory.deployVault(underlying);
    }
}

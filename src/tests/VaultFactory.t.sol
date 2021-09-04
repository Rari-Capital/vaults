// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultFactoryTest is DSTestPlus {
    VaultFactory vaultFactory;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vaultFactory = new VaultFactory();
    }

    function test_deploy_vault() public {
        Vault vault = vaultFactory.deployVault(underlying);

        assertVaultEq(vaultFactory.getVaultFromUnderlying(underlying), vault);
        assertTrue(vaultFactory.isVaultDeployed(vault));
        assertERC20Eq(vault.underlying(), underlying);
    }

    function testFail_does_not_allow_duplicate_vaults() public {
        test_deploy_vault();
        test_deploy_vault();
    }
}

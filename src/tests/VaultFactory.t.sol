// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultFactoryTest is DSTestPlus {
    VaultFactory vaultFactory;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20();
        vaultFactory = new VaultFactory();
    }

    function test_deploy_vault() public {
        Vault vault = vaultFactory.deploy(underlying);
        assertErc20Eq(vault.underlying(), underlying);
        assertVaultEq(vaultFactory.getVaultFromUnderlying(underlying), vault);
    }

    function testFail_does_not_allow_duplicate_vaults() public {
        test_deploy_vault();
        test_deploy_vault();
    }
}

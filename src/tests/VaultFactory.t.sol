// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultFactoryTest is DSTest {
    VaultFactory vaultFactory;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20();
        vaultFactory = new VaultFactory();
    }

    function test_deploy_vault() public {
        Vault vault = vaultFactory.deploy(underlying);
        assertEq(address(vault.underlying()), address(underlying));
    }

    function testFail_does_not_allow_duplicate_vault() public {
        test_deploy_vault();
        test_deploy_vault();
    }
}

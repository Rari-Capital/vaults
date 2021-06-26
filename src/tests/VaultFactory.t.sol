// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "./mocks/MockERC20.sol";

import "../Vault.sol";
import "../VaultFactory.sol";

contract VaultFactoryTest is DSTest {
    VaultFactory vaultFactory;
    MockERC20 underlying;

    function setUp() public {
        vaultFactory = new VaultFactory();
        underlying = new MockERC20();
    }

    function test_deploy_vault() public {
        Vault vault = vaultFactory.deploy(underlying);
        assertTrue(address(vault) != address(0));
    }

    function testFail_does_not_allow_duplicate_vault() public {
        test_deploy_vault();
        test_deploy_vault();
    }
}

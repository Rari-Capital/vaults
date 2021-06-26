// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";

import "./Vault.sol";

contract VaultsTest is DSTest {
  Vault vault;

  function setUp() public {
    vault = new Vault();
  }

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "lib/ds-test/src/test.sol";

import "./Vaults.sol";

contract VaultsTest is DSTest {
  Vaults vaults;

  function setUp() public {
    vaults = new Vaults();
  }

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";

import "../VaultFactory.sol";

contract VaultsTest is DSTest {
  VaultFactory vaultFactory;

  function setUp() public {
    vaultFactory = new VaultFactory();
  }
}

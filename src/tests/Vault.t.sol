// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";

import "../Vault.sol";

contract VaultsTest is DSTest {
  Vault vault;
  ERC20 testUnderlyingToken;

  function setUp() public {
    testUnderlyingToken = new ERC20("Dai Stablecoin", "DAI");
    vault = new Vault(testUnderlyingToken);
  }

  function test_properly_init_erc20() public {
    assertEq(address(vault.underlying()), address(testUnderlyingToken));

    assertEq(
      vault.name(),
      StringConcat.concat("Fuse ", testUnderlyingToken.name(), " Vault")
    );

    assertEq(
      vault.symbol(),
      StringConcat.concat("fv", testUnderlyingToken.symbol())
    );
  }
}

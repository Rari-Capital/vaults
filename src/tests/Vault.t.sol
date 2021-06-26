// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";

import "./mocks/MockERC20.sol";

import "../Vault.sol";

contract VaultsTest is DSTest {
  Vault vault;
  MockERC20 underlying;

  function setUp() public {
    underlying = new MockERC20();
    vault = new Vault(underlying);
  }

  function test_properly_init_erc20() public {
    assertEq(address(vault.underlying()), address(underlying));

    assertEq(
      vault.name(),
      StringConcat.concat("Fuse ", underlying.name(), " Vault")
    );

    assertEq(vault.symbol(), StringConcat.concat("fv", underlying.symbol()));
  }

  function test_deposit_withdraw(uint256 amount) public {
    underlying.mintIfNeeded(address(this), amount);
    underlying.approve(address(vault), amount);

    assertEq(underlying.balanceOf(address(this)), amount);
    assertEq(vault.balanceOf(address(this)), 0);
    vault.deposit(amount);

    assertEq(underlying.balanceOf(address(this)), 0);
    assertEq(vault.balanceOf(address(this)), amount);

    vault.withdraw(amount);
    assertEq(underlying.balanceOf(address(this)), amount);
    assertEq(vault.balanceOf(address(this)), 0);
  }
}

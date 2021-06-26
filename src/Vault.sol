// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./libraries/ERC20.sol";
import "./libraries/StringConcat.sol";

contract Vault is ERC20 {
  /// @notice The underlying token for the vault.
  ERC20 public immutable underlying;

  /// @notice Creates a new vault based on an underlying token.
  /// @param _underlying An underlying ERC20 compliant token.
  constructor(ERC20 _underlying)
    ERC20(
      // ex: Fuse DAI Vault
      StringConcat.concat("Fuse ", _underlying.name(), " Vault"),
      // fvDAI
      StringConcat.concat("fv", _underlying.symbol())
    )
  {
    underlying = _underlying;
  }
}

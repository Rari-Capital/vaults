// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

library StringConcat {
  function concat(
    string memory arg1,
    string memory arg2,
    string memory arg3
  ) internal pure returns (string memory) {
    return string(abi.encodePacked(arg1, arg2, arg3));
  }

  function concat(string memory arg1, string memory arg2)
    internal
    pure
    returns (string memory)
  {
    return string(abi.encodePacked(arg1, arg2));
  }
}

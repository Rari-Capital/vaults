// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "ds-test/test.sol";

import {Vault} from "../../Vault.sol";

import {ERC20} from "../../external/ERC20.sol";

contract DSTestPlus is DSTest {
    Hevm constant hevm = Hevm(HEVM_ADDRESS);

    address immutable self = address(this);

    function assertVaultEq(Vault va, Vault vb) public {
        assertEq(address(va), address(vb));
    }

    function assertErc20Eq(ERC20 ea, ERC20 eb) public {
        assertEq(address(ea), address(eb));
    }
}

interface Hevm {
    function warp(uint256) external;

    function roll(uint256) external;
}

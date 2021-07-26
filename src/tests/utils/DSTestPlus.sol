// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import "ds-test/test.sol";

import {ERC20} from "solmate/erc20/ERC20.sol";

import {Vault} from "../../Vault.sol";

contract DSTestPlus is DSTest {
    Hevm constant hevm = Hevm(HEVM_ADDRESS);

    address immutable self = address(this);

    function assertVaultEq(Vault va, Vault vb) public {
        assertEq(address(va), address(vb));
    }

    function assertERC20Eq(ERC20 ea, ERC20 eb) public {
        assertEq(address(ea), address(eb));
    }
}

interface Hevm {
    function warp(uint256) external;

    function roll(uint256) external;
}

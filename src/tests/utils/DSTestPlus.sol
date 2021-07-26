// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {DSTestPlus as DSTest} from "solmate/tests/utils/DSTestPlus.sol";

import {Vault} from "../../Vault.sol";

contract DSTestPlus is DSTest {
    function assertVaultEq(Vault va, Vault vb) public {
        assertEq(address(va), address(vb));
    }
}

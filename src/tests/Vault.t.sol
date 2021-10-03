// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Vault} from "../Vault.sol";

contract VaultsTest is DSTestPlus {
    Vault vault;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);
    }
}

pragma solidity ^0.6.7;

import "ds-test/test.sol";

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

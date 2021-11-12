// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {TrustAuthority} from "solmate/auth/authorities/TrustAuthority.sol";

import {VaultAuthorityModule} from "../modules/VaultAuthorityModule.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";

contract VaultAuthorityModuleTest is DSTestPlus {
    VaultFactory vaultFactory;

    Vault vault;
    MockERC20 underlying;

    VaultAuthorityModule vaultAuthorityModule;

    TrustAuthority trustAuthority;

    function setUp() public {
        vaultAuthorityModule = new VaultAuthorityModule(address(this), Authority(address(0)));

        vaultFactory = new VaultFactory(address(this), vaultAuthorityModule);

        underlying = new MockERC20("Mock Token", "TKN", 18);

        vault = vaultFactory.deployVault(underlying);

        trustAuthority = new TrustAuthority(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                          ROLE ASSIGNMENT TESTS  
    //////////////////////////////////////////////////////////////*/

    function testSetRoles() public {
        assertFalse(vaultAuthorityModule.doesUserHaveRole(address(0xBEEF), 0));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, true);

        assertTrue(vaultAuthorityModule.doesUserHaveRole(address(0xBEEF), 0));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, false);

        assertFalse(vaultAuthorityModule.doesUserHaveRole(address(0xBEEF), 0));
    }

    function testSetRootUser() public {
        assertFalse(vaultAuthorityModule.isUserRoot(address(0xBEEF)));

        vaultAuthorityModule.setRootUser(address(0xBEEF), true);

        assertTrue(vaultAuthorityModule.isUserRoot(address(0xBEEF)));

        vaultAuthorityModule.setRootUser(address(0xBEEF), false);

        assertFalse(vaultAuthorityModule.isUserRoot(address(0xBEEF)));
    }

    /*///////////////////////////////////////////////////////////////
                      ROLE CAPABILITY UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetRoleCapabilities() public {
        assertFalse(vaultAuthorityModule.doesRoleHaveCapability(0, Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, true);

        assertTrue(vaultAuthorityModule.doesRoleHaveCapability(0, Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, false);

        assertFalse(vaultAuthorityModule.doesRoleHaveCapability(0, Vault.setFeePercent.selector));
    }

    /*///////////////////////////////////////////////////////////////
                   TARGET CUSTOM AUTHORITY UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetTargetCustomAuthority() public {
        assertEq(address(vaultAuthorityModule.getTargetCustomAuthority(address(0xBEEF))), address(0));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xBEEF), Authority(address(0xCAFE)));

        assertEq(address(vaultAuthorityModule.getTargetCustomAuthority(address(0xBEEF))), address(0xCAFE));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xBEEF), Authority(address(0)));

        assertEq(address(vaultAuthorityModule.getTargetCustomAuthority(address(0xBEEF))), address(0));
    }

    /*///////////////////////////////////////////////////////////////
                           AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCanCallWithAuthorizedRole() public {
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, true);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));
    }

    function testRootUserCanCall() public {
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRootUser(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRootUser(address(0xBEEF), false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0), Vault.setFeePercent.selector));
    }

    function testCanCallWithCustomAuthority() public {
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), trustAuthority);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), Authority(address(0)));
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));
    }

    function testCanCallWithCustomAuthorityOverridesRootUser() public {
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRootUser(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), trustAuthority);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRootUser(address(0xBEEF), false);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), Authority(address(0)));
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRootUser(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));
    }

    function testCanCallWithCustomAuthorityOverridesUserWithRole() public {
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, true);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), trustAuthority);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, false);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setTargetCustomAuthority(address(0xCAFE), Authority(address(0)));
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        trustAuthority.setIsTrusted(address(0xBEEF), true);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, true);
        assertTrue(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setRoleCapability(0, Vault.setFeePercent.selector, false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));

        vaultAuthorityModule.setUserRole(address(0xBEEF), 0, false);
        assertFalse(vaultAuthorityModule.canCall(address(0xBEEF), address(0xCAFE), Vault.setFeePercent.selector));
    }
}

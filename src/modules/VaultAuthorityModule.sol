// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {RolesAuthority} from "solmate/auth/authorities/RolesAuthority.sol";

/// @title Rari Vault Authority Module
/// @notice Module for managing access to secured Vault operations.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/authorities/RolesAuthority.sol)
contract VaultAuthorityModule is Auth(msg.sender, Authority(address(0))), Authority {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event TargetCustomAuthorityUpdated(address indexed target, Authority indexed authority);

    event UserRootUpdated(address indexed user, bool enabled);

    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);

    event RoleCapabilityUpdated(uint8 indexed role, bytes4 indexed functionSig, bool enabled);

    /*///////////////////////////////////////////////////////////////
                       CUSTOM TARGET AUTHORITY STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps targets to a custom Authority to use for authorization.
    mapping(address => Authority) public getCustomAuthority;

    /*///////////////////////////////////////////////////////////////
                             USER ROLE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps users to a boolean indicating whether they have root access.
    mapping(address => bool) public isUserRoot;

    /// @notice Maps users to a bytes32 set of all the roles assigned to them.
    mapping(address => bytes32) public getUserRoles;

    /*///////////////////////////////////////////////////////////////
                        ROLE CAPABILITY STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Maps function signature to a set of all roles that can call the given function.
    mapping(bytes4 => bytes32) public getRoleCapabilities;

    /// @notice Gets whether a user has a specific role.
    /// @param user The user to check for.
    /// @param role The role to check if the user has.
    /// @return A boolean indicating whether the user has the role.
    function doesUserHaveRole(address user, uint8 role) external view returns (bool) {
        unchecked {
            // Generate a mask for the role.
            bytes32 shifted = bytes32(uint256(uint256(2)**uint256(role)));

            // Check if the user has the role using the generated mask.
            return bytes32(0) != getUserRoles[user] & shifted;
        }
    }

    /// @notice Returns if a user can call a given Vault's function.
    /// @param user The user to check for.
    /// @param target The Vault the user is trying to call.
    /// @param functionSig The function signature the user is trying to call.
    /// @return A boolean indicating if the user can call the function on the Vault.
    /// @dev First checks if the user is authorized to call all Vault's with the given function.
    /// If they are not it then checks if the Vault has a custom Authority. If so it returns whether
    /// it the user is authorized to call the function, otherwise execution ends and it returns false.
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view override returns (bool) {
        // Get the user's role set.
        bytes32 userRoles = getUserRoles[user];

        // Get the set of roles authorized to call the function.
        bytes32 rolesAuthorized = getRoleCapabilities[functionSig];

        // Check if the user has an authorized role or is root and return true if so.
        if (bytes32(0) != userRoles & rolesAuthorized || isUserRoot[user]) return true;

        // Get the target's custom Authority.
        Authority customAuthority = getCustomAuthority[target];

        // If a custom authority is set, return whether the Authority allows the user to call the function.
        return address(customAuthority) != address(0) && customAuthority.canCall(user, target, functionSig);
    }

    /*///////////////////////////////////////////////////////////////
               CUSTOM TARGET AUTHORITY CONFIGURATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a custom Authority for a target.
    /// @param target The target to set a custom Authority for.
    /// @param customAuthority The custom Authority to set.
    function setTargetCustomAuthority(address target, Authority customAuthority) external requiresAuth {
        // Update the target's custom Authority.
        getCustomAuthority[target] = customAuthority;

        emit TargetCustomAuthorityUpdated(target, customAuthority);
    }

    /*///////////////////////////////////////////////////////////////
                  ROLE CAPABILITY CONFIGURATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a capability for a role.
    /// @param role The role to set a capability for.
    /// @param functionSig The function to enable the role to call or not.
    /// @param enabled Whether the role should be able to call the function or not.
    function setRoleCapability(
        uint8 role,
        bytes4 functionSig,
        bool enabled
    ) external requiresAuth {
        // Get the previous role capability set.
        bytes32 lastRoles = getRoleCapabilities[functionSig];

        unchecked {
            // Generate a mask for the role.
            bytes32 shifted = bytes32(uint256(uint256(2)**uint256(role)));

            // Update the role's capability set with the role mask.
            getRoleCapabilities[functionSig] = enabled ? lastRoles | shifted : lastRoles & ~shifted;
        }

        emit RoleCapabilityUpdated(role, functionSig, enabled);
    }

    /*///////////////////////////////////////////////////////////////
                      USER ROLE ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Assigns a role to a user.
    /// @param user The user to assign a role to.
    /// @param role The role to assign to the user.
    /// @param enabled Whether the user should have the role or not.
    function setUserRole(
        address user,
        uint8 role,
        bool enabled
    ) external requiresAuth {
        // Get the previous set of roles.
        bytes32 lastRoles = getUserRoles[user];

        unchecked {
            // Generate a mask for the role.
            bytes32 shifted = bytes32(uint256(uint256(2)**uint256(role)));

            // Update the user's role set with the role mask.
            getUserRoles[user] = enabled ? lastRoles | shifted : lastRoles & ~shifted;
        }

        emit UserRoleUpdated(user, role, enabled);
    }

    /// @notice Sets a user as a root user.
    /// @param user The user to set as a root user.
    /// @param enabled Whether the user should be a root user or not.
    function setRootUser(address user, bool enabled) external requiresAuth {
        // Update whether the user is a root user.
        isUserRoot[user] = enabled;

        emit UserRootUpdated(user, enabled);
    }
}

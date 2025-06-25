// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IRoleManager
/// @notice Interface for role management with explicit visibility and renounceRole support.
/// @dev Defines role-based access control functions for interacting contracts.
interface IRoleManager {
    /// @notice Returns the OPERATOR_ROLE identifier.
    /// @return The role identifier as a bytes32.
    function OPERATOR_ROLE() external view returns (bytes32);

    /// @notice Returns the VAULT_ADMIN_ROLE identifier.
    /// @return The role identifier as a bytes32.
    function VAULT_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns the ROUTER_ADMIN_ROLE identifier.
    /// @return The role identifier as a bytes32.
    function ROUTER_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Checks if an account has a specific role.
    /// @param role The role identifier to check.
    /// @param account The account to verify.
    /// @return True if the account has the role, false otherwise.
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Returns the admin role for a given role.
    /// @param role The role to query.
    /// @return The admin role identifier as a bytes32.
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /// @notice Reverts to enforce use of proposeGrantRole for granting roles.
    /// @param role The role to grant.
    /// @param account The account to receive the role.
    /// @dev This function is disabled to ensure timelocked role changes.
    function grantRole(bytes32 role, address account) external;

    /// @notice Reverts to enforce use of proposeRevokeRole for revoking roles.
    /// @param role The role to revoke.
    /// @param account The account to lose the role.
    /// @dev This function is disabled to ensure timelocked role changes.
    function revokeRole(bytes32 role, address account) external;

    /// @notice Reverts to enforce use of proposeRevokeRole for renouncing roles.
    /// @param role The role to renounce.
    /// @param account The account renouncing the role.
    /// @dev This function is disabled to ensure timelocked role changes.
    function renounceRole(bytes32 role, address account) external;
}
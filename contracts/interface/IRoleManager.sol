// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoleManager {
    function OPERATOR_ROLE() external view returns (bytes32);
    function VAULT_ADMIN_ROLE() external view returns (bytes32);
    function ROUTER_ADMIN_ROLE() external view returns (bytes32);
    
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}
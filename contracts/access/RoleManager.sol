// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleManager is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");

    constructor(address _superAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(VAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ROUTER_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        
        _grantRole(OPERATOR_ROLE, _superAdmin);
        _grantRole(VAULT_ADMIN_ROLE, _superAdmin);
        _grantRole(ROUTER_ADMIN_ROLE, _superAdmin);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
}

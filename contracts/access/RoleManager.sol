// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title RoleManager
/// @notice Manages roles with timelocked role changes and admin transfer, intended for use with a multi-sig admin.
/// @dev Inherits AccessControl for role management and Pausable for emergency stops.
contract RoleManager is AccessControl, Pausable {
    /// @notice Identifier for the OPERATOR_ROLE.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Identifier for the VAULT_ADMIN_ROLE.
    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");

    /// @notice Identifier for the ROUTER_ADMIN_ROLE.
    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");

    /// @notice Minimum timelock delay for role changes (24 hours).
    uint256 public  MIN_TIMELOCK_DELAY = 1 days;

    /// @notice Struct to store pending role actions.
    struct PendingRoleAction {
        bytes32 role; // The role to grant or revoke
        address account; // The account affected
        bool isGrant; // True for grant, false for revoke
        uint256 executableAfter; // Timestamp when action can be executed
    }

    /// @notice Struct to store pending admin transfers.
    struct PendingAdminTransfer {
        address newAdmin; // The proposed new admin
        address oldAdmin; // The current admin
        uint256 executableAfter; // Timestamp when transfer can be executed
    }

    /// @notice Mapping of action ID to pending role action.
    mapping(bytes32 => PendingRoleAction) public pendingRoleActions;

    /// @notice Mapping of new admin address to pending admin transfer.
    mapping(address => PendingAdminTransfer) public pendingAdminTransfers;

    /// @notice Emitted when a role change is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param role The role to grant or revoke.
    /// @param account The account affected.
    /// @param isGrant True for grant, false for revoke.
    /// @param executableAfter Timestamp when the action can be executed.
    event RoleChangeProposed(
        bytes32 indexed actionId,
        bytes32 indexed role,
        address indexed account,
        bool isGrant,
        uint256 executableAfter
    );

    /// @notice Emitted when a role change is executed.
    /// @param actionId The identifier of the executed action.
    /// @param role The role granted or revoked.
    /// @param account The account affected.
    /// @param isGrant True for grant, false for revoke.
    event RoleChangeExecuted(
        bytes32 indexed actionId,
        bytes32 indexed role,
        address indexed account,
        bool isGrant
    );

    /// @notice Emitted when a role change proposal is cancelled.
    /// @param actionId The identifier of the cancelled action.
    event RoleChangeCancelled(bytes32 indexed actionId);

    /// @notice Emitted when a new admin is proposed.
    /// @param currentAdmin The current admin proposing the transfer.
    /// @param newAdmin The proposed new admin.
    event AdminTransferProposed(address indexed currentAdmin, address indexed newAdmin);

    /// @notice Emitted when the admin role is transferred.
    /// @param oldAdmin The previous admin.
    /// @param newAdmin The new admin.
    event AdminTransferAccepted(address indexed oldAdmin, address indexed newAdmin);

    /// @notice Emitted when the timelock delay period is changed
    /// @param oldDelay The previous delay duration in seconds
    /// @param newDelay The new delay duration in seconds
    /// @dev This event provides transparency about timelock parameter changes
    event TimelockDelayChanged(uint256 oldDelay, uint256 newDelay);



    /// @notice Initializes the contract with a multi-sig admin.
    /// @param _multiSigAdmin Address of the multi-signature wallet to be granted admin roles.
    /// @dev Grants DEFAULT_ADMIN_ROLE, OPERATOR_ROLE, VAULT_ADMIN_ROLE, and ROUTER_ADMIN_ROLE to the admin.
    constructor(address _multiSigAdmin) {
        require(_multiSigAdmin != address(0), "Invalid admin address");
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigAdmin);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(VAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ROUTER_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(OPERATOR_ROLE, _multiSigAdmin);
        _grantRole(VAULT_ADMIN_ROLE, _multiSigAdmin);
        _grantRole(ROUTER_ADMIN_ROLE, _multiSigAdmin);
    }

    /// @notice Proposes granting a role to an account, subject to timelock.
    /// @param role The role to grant.
    /// @param account The account to receive the role.
    /// @dev Only callable by the role admin. Reverts if paused, account is invalid, or action is already proposed. Emits RoleChangeProposed event.
    function proposeGrantRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) whenNotPaused {
        require(account != address(0), "Invalid account");
        bytes32 actionId = keccak256(abi.encode(role, account, true, block.timestamp));
        require(pendingRoleActions[actionId].executableAfter == 0, "Action already proposed");

        pendingRoleActions[actionId] = PendingRoleAction({
            role: role,
            account: account,
            isGrant: true,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });

        emit RoleChangeProposed(actionId, role, account, true, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Proposes revoking a role from an account, subject to timelock.
    /// @param role The role to revoke.
    /// @param account The account to lose the role.
    /// @dev Only callable by the role admin. Reverts if paused, account is invalid, or action is already proposed. Emits RoleChangeProposed event.
    function proposeRevokeRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) whenNotPaused {
        require(account != address(0), "Invalid account");
        bytes32 actionId = keccak256(abi.encode(role, account, false, block.timestamp));
        require(pendingRoleActions[actionId].executableAfter == 0, "Action already proposed");

        pendingRoleActions[actionId] = PendingRoleAction({
            role: role,
            account: account,
            isGrant: false,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });

        emit RoleChangeProposed(actionId, role, account, false, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes a proposed role change after the timelock period.
    /// @param actionId The identifier of the proposed action.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Reverts if action is not proposed or timelock is not expired. Emits RoleChangeExecuted event.
    function executeRoleAction(bytes32 actionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PendingRoleAction memory action = pendingRoleActions[actionId];
        require(action.executableAfter != 0, "Action not proposed");
        require(block.timestamp >= action.executableAfter, "Timelock not expired");

        if (action.isGrant) {
            _grantRole(action.role, action.account);
        } else {
            _revokeRole(action.role, action.account);
        }

        emit RoleChangeExecuted(actionId, action.role, action.account, action.isGrant);
        delete pendingRoleActions[actionId];
    }

    /// @notice Cancels a proposed role action.
    /// @param actionId The identifier of the proposed action.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Reverts if action is not proposed. Emits RoleChangeCancelled event.
    function cancelRoleAction(bytes32 actionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(pendingRoleActions[actionId].executableAfter != 0, "Action not proposed");
        delete pendingRoleActions[actionId];
        emit RoleChangeCancelled(actionId);
    }

    /// @notice Proposes transferring the DEFAULT_ADMIN_ROLE to a new address.
    /// @param newAdmin The address to receive the admin role.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Reverts if paused or newAdmin is invalid. Emits AdminTransferProposed event.
    function proposeAdminTransfer(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(newAdmin != address(0), "Invalid admin address");
        pendingAdminTransfers[newAdmin] = PendingAdminTransfer({
            newAdmin: newAdmin,
            oldAdmin: msg.sender,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit AdminTransferProposed(msg.sender, newAdmin);
    }

    /// @notice Accepts the DEFAULT_ADMIN_ROLE transfer.
    /// @dev Reverts if no transfer is proposed, timelock is not expired, or old admin lacks role. Emits AdminTransferAccepted event.
    function acceptAdminTransfer() external {
        PendingAdminTransfer memory transfer = pendingAdminTransfers[msg.sender];
        require(hasRole(DEFAULT_ADMIN_ROLE, transfer.oldAdmin), "Old admin lacks DEFAULT_ADMIN_ROLE");
        require(transfer.executableAfter != 0, "No transfer proposed");
        require(block.timestamp >= transfer.executableAfter, "Timelock not expired");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, transfer.oldAdmin);
        emit AdminTransferAccepted(transfer.oldAdmin, msg.sender);
        delete pendingAdminTransfers[msg.sender];
    }

    /// @notice Sets the timelock delay period
    /// @param role The role to setTimelock.
    /// @param daysCount Number of days for the delay (will be converted to seconds)
    function setTimelock( bytes32 role , uint256 daysCount ) external onlyRole(getRoleAdmin(role)){
            require(daysCount > 0, "Delay must be at least 1 day");
            uint256 newDelay = daysCount * 1 days;
            emit TimelockDelayChanged(MIN_TIMELOCK_DELAY, newDelay);
            MIN_TIMELOCK_DELAY = newDelay;
    }

    /// @notice Overrides renounceRole to disable direct calls.
    /// @param role The role to renounce.
    /// @param account The account renouncing the role.
    /// @dev Reverts to enforce use of proposeRevokeRole.
    function renounceRole(bytes32 role, address account) public override {
        revert("Use proposeRevokeRole instead");
    }

    /// @notice Overrides grantRole to disable direct calls.
    /// @param role The role to grant.
    /// @param account The account to receive the role.
    /// @dev Reverts to enforce use of proposeGrantRole.
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        revert("Use proposeGrantRole instead");
    }

    /// @notice Overrides revokeRole to disable direct calls.
    /// @param role The role to revoke.
    /// @param account The account to lose the role.
    /// @dev Reverts to enforce use of proposeRevokeRole.
    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        revert("Use proposeRevokeRole instead");
    }

    /// @notice Pauses role management operations.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Inherits from Pausable.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses role management operations.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Inherits from Pausable.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
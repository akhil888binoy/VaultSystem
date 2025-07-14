// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IVault.sol";
import "../interface/IRoleManager.sol";

/// @title Timelock
/// @notice Manages delayed execution of sensitive actions for WalletRouter and Vault.
/// @dev Uses a 24-hour timelock delay to ensure security for critical operations.
contract Timelock {
    /// @notice Struct to store pending WalletRouter actions.
    struct PendingWalletRouter {
        bytes32 key; // Action identifier
        address newvault; // Proposed new vault address
        uint256 executableAfter; // Timestamp when action can be executed
    }

    /// @notice Struct to store pending Vault actions.
    struct PendingVault {
        bytes32 key; // Action identifier
        address target; // Target address (token or WalletRouter)
        uint256 executableAfter; // Timestamp when action can be executed
    }

    /// @notice Emitted when a new vault address is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param newvault The proposed new vault address.
    /// @param executableAfter Timestamp when the action can be executed.
    event SetVaultPropose(bytes32 indexed actionId, address indexed newvault, uint256 executableAfter);

    /// @notice Emitted when a token addition is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to add.
    /// @param executableAfter Timestamp when the action can be executed.
    event AddTokenPropose(bytes32 indexed actionId, address indexed token, uint256 executableAfter);

    /// @notice Emitted when a token removal is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to remove.
    /// @param executableAfter Timestamp when the action can be executed.
    event RemoveTokenPropose(bytes32 indexed actionId, address indexed token, uint256 executableAfter);

    /// @notice Emitted when a new WalletRouter address is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param walletRouter The proposed new WalletRouter address.
    /// @param executableAfter Timestamp when the action can be executed.
    event SetWalletRouterPropose(bytes32 indexed actionId, address indexed walletRouter, uint256 executableAfter);

    /// @notice Emitted when fund recovery is proposed.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to recover.
    /// @param recipient The address to receive the recovered funds.
    /// @param amount The amount to recover.
    /// @param executableAfter Timestamp when the action can be executed.
    event RecoverFundsPropose(
        bytes32 indexed actionId,
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 executableAfter
    );

    /// @notice Mapping of action ID to pending WalletRouter action.
    mapping(bytes32 => PendingWalletRouter) public pendingWalletRouter;

    /// @notice Mapping of action ID to pending Vault action.
    mapping(bytes32 => PendingVault) public pendingVault;

    /// @notice Minimum timelock delay for changes (24 hours).
    uint256 public constant MIN_TIMELOCK_DELAY = 1 days;

    /// @notice Address of the RoleManager contract for access control.
    IRoleManager public roleManager;

    /// @notice Initializes the contract with a RoleManager address.
    /// @param _roleManager Address of the RoleManager contract.
    /// @dev Reverts if the RoleManager address is invalid.
    constructor(address _roleManager) {
        require(_roleManager != address(0), "Invalid RoleManager");
        roleManager = IRoleManager(_roleManager);
    }

    /// @notice Restricts function access to accounts with the ROUTER_ADMIN_ROLE.
    /// @param caller The address to check.
    /// @dev Reverts if the caller does not have the ROUTER_ADMIN_ROLE.
    modifier onlyRouterAdmin(address caller) {
        require(roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), caller), "Only Router Admin can call this function");
        _;
    }

    /// @notice Restricts function access to accounts with the VAULT_ADMIN_ROLE.
    /// @param caller The address to check.
    /// @dev Reverts if the caller does not have the VAULT_ADMIN_ROLE.
    modifier onlyVaultAdmin(address caller) {
        require(roleManager.hasRole(roleManager.VAULT_ADMIN_ROLE(), caller), "Caller lacks VAULT_ADMIN_ROLE");
        _;
    }


    /// @notice Proposes setting a new WalletRouter address for the Vault.
    /// @param _walletAddress The proposed new WalletRouter address.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if action is already proposed. Emits SetWalletRouterPropose event.
    function proposeSetWalletRouter(address _walletAddress, bytes32 key, address caller) external onlyVaultAdmin(caller) {
        bytes32 actionId = keccak256(abi.encode(key, _walletAddress, block.timestamp));
        require(pendingVault[actionId].executableAfter == 0, "Action already proposed");
        pendingVault[actionId] = PendingVault({
            key: key,
            target: _walletAddress,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit SetWalletRouterPropose(actionId, _walletAddress, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes the setting of a new WalletRouter address after timelock validation.
    /// @param actionId The identifier of the proposed action.
    /// @param _walletRouter The new WalletRouter address.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if action is not proposed, timelock is not expired, or WalletRouter is mismatched.
    function executeSetWalletRouter(bytes32 actionId, address _walletRouter, address caller) external onlyVaultAdmin(caller) returns (bool) {
        PendingVault memory action = pendingVault[actionId];
        require(action.executableAfter != 0, "Action not proposed");
        require(block.timestamp >= action.executableAfter, "Timelock not expired");
        require(action.key == keccak256("SET_WALLETROUTER"), "Invalid key");
        require(action.target == _walletRouter, "WalletRouter mismatch");
        delete pendingVault[actionId];
        return true;
    }

    /// @notice Proposes recovering funds from the Vault.
    /// @param token The token address to recover.
    /// @param recipient The address to receive the recovered funds.
    /// @param amount The amount to recover.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if action is already proposed. Emits RecoverFundsPropose event.
    function proposeRecoverFunds(address token, address recipient, uint256 amount, bytes32 key, address caller) external onlyVaultAdmin(caller) {
        bytes32 actionId = keccak256(abi.encode(key, token, recipient, amount, block.timestamp));
        require(pendingVault[actionId].executableAfter == 0, "Action already proposed");
        pendingVault[actionId] = PendingVault({
            key: key,
            target: token,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit RecoverFundsPropose(actionId, token, recipient, amount, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes the recovery of funds after timelock validation.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to recover.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if action is not proposed, timelock is not expired, or token is mismatched.
    function executeRecoverFunds(bytes32 actionId, address token, address caller) external onlyVaultAdmin(caller) returns (bool) {
        PendingVault memory action = pendingVault[actionId];
        require(action.executableAfter != 0, "Action not proposed");
        require(block.timestamp >= action.executableAfter, "Timelock not expired");
        require(action.key == keccak256("RECOVER_FUNDS"), "Invalid key");
        require(action.target == token, "Token mismatch");
        delete pendingVault[actionId];
        return true;
    }
}
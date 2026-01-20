// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IRoleManager.sol";
import "../error/Error.sol";
/// @title Timelock
/// @notice Manages delayed execution of sensitive actions for WalletRouter and Vault contracts.
/// @dev Implements a timelock mechanism with a minimum 24-hour delay to ensure security for critical operations.
contract Timelock {
    /// @notice Struct to store pending WalletRouter actions.
    /// @param key Unique identifier for the action.
    /// @param newvault Proposed new Vault address.
    /// @param executableAfter Timestamp after which the action can be executed.
    struct PendingWalletRouter {
        bytes32 key;
        address newvault;
        uint256 executableAfter;
    }

    /// @notice Struct to store pending Vault actions.
    /// @param key Unique identifier for the action.
    /// @param target Target address (e.g., token or WalletRouter).
    /// @param executableAfter Timestamp after which the action can be executed.
    struct PendingVault {
        bytes32 key;
        address target;
        uint256 executableAfter;
    }

    /// @notice Struct to store pending fund recovery actions.
    /// @param key Unique identifier for the action.
    /// @param token Address of the token to recover.
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens to recover.
    /// @param executableAfter Timestamp after which the action can be executed.
    struct PendingRecoverFunds {
        bytes32 key;
        address token;
        address recipient;
        uint256 amount;
        uint256 executableAfter;
    }

    /// @notice Struct to store pending dust sweep actions.
    /// @param key Unique identifier for the action.
    /// @param token Address of the token to sweep.
    /// @param to Address to receive the swept tokens.
    /// @param amount Amount of tokens to sweep.
    /// @param executableAfter Timestamp after which the action can be executed.
    struct PendingSweepDust {
        bytes32 key;
        address token;
        address to;
        uint256 amount;
        uint256 executableAfter;
    }

    /// @notice Emitted when a new WalletRouter address is proposed for the Vault.
    /// @param actionId Unique identifier of the proposed action.
    /// @param walletRouter Proposed new WalletRouter address.
    /// @param executableAfter Timestamp after which the action can be executed.
    event SetWalletRouterPropose(bytes32 indexed actionId, address indexed walletRouter, uint256 executableAfter);

    /// @notice Emitted when a dust sweep action is proposed.
    /// @param actionId Unique identifier of the proposed action.
    /// @param to Address to receive the swept tokens.
    /// @param token Address of the token to sweep.
    /// @param amount Amount of tokens to sweep.
    /// @param executableAfter Timestamp after which the action can be executed.
    event SweepDustPropose(bytes32 indexed actionId, address indexed to, address indexed token, uint256 amount, uint256 executableAfter);

    /// @notice Emitted when a fund recovery action is proposed.
    /// @param actionId Unique identifier of the proposed action.
    /// @param token Address of the token to recover.
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens to recover.
    /// @param executableAfter Timestamp after which the action can be executed.
    event RecoverFundsPropose(
        bytes32 indexed actionId,
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 executableAfter
    );

    /// @notice Emitted when the timelock delay period is changed.
    /// @param oldDelay Previous delay duration in seconds.
    /// @param newDelay New delay duration in seconds.
    event TimelockDelayChanged(uint256 oldDelay, uint256 newDelay);

    /// @notice Emitted when the Vault address is updated.
    /// @param vault New Vault address.
    event VaultSet(address indexed vault);

    /// @notice Mapping of action ID to pending WalletRouter action.
    mapping(bytes32 => PendingWalletRouter) public pendingWalletRouter;

    /// @notice Mapping of action ID to pending Vault action.
    mapping(bytes32 => PendingVault) public pendingVault;

    /// @notice Mapping of action ID to pending fund recovery action.
    mapping(bytes32 => PendingRecoverFunds) public pendingRecoverFunds;

    /// @notice Mapping of action ID to pending dust sweep action.
    mapping(bytes32 => PendingSweepDust) public pendingSweepDust;

    /// @notice Minimum timelock delay for actions (default: 24 hours).
    uint256 public MIN_TIMELOCK_DELAY = 1 days;

    /// @notice Address of the RoleManager contract for access control.
    IRoleManager public roleManager;

    /// @dev Address of the Vault contract.
    address public vault;

    /// @notice Initializes the contract with a RoleManager address.
    /// @param _roleManager Address of the RoleManager contract.
    /// @dev Reverts if the provided RoleManager address is zero.
    constructor(address _roleManager) {
        if (_roleManager == address(0)) revert  Error.InvalidRoleManager();
        roleManager = IRoleManager(_roleManager);
    }

    /// @notice Restricts function access to accounts with the ROUTER_ADMIN_ROLE.
    /// @dev Reverts if the caller does not have the ROUTER_ADMIN_ROLE.
    modifier onlyRouterAdmin() {
        if (!roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), msg.sender)) revert  Error.OnlyRouterAdmin();
        _;
    }

    /// @notice Restricts function access to the Vault contract.
    /// @dev Reverts if the caller is not the Vault contract.
    modifier onlyVault() {
        if (msg.sender != vault) revert Error.OnlyVault();
        _;
    }

    /// @notice Sets the Vault address.
    /// @param _vault Address of the new Vault contract.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Reverts if the Vault address is zero. Emits VaultSet event.
    function setVault(address _vault) external onlyRouterAdmin {
        if (_vault == address(0)) revert  Error.InvalidVaultAddress();
        vault = _vault;
        emit VaultSet(_vault);
    }

    /// @notice Proposes a dust sweep action for the Vault.
    /// @param token Address of the token to sweep.
    /// @param to Address to receive the swept tokens.
    /// @param amount Amount of tokens to sweep.
    /// @param key Unique identifier for the action.
    /// @dev Only callable by the Vault. Reverts if the action is already proposed. Emits SweepDustPropose event.
    function proposeSweepDust(
        address token,
        address to,
        uint256 amount,
        bytes32 key
    ) external onlyVault {
        bytes32 actionId = keccak256(abi.encode(key, token, to, amount, block.timestamp));
        if (pendingSweepDust[actionId].executableAfter != 0) revert Error.ActionAlreadyProposed();
        
        pendingSweepDust[actionId] = PendingSweepDust({
            key: key,
            token: token,
            to: to,
            amount: amount,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit SweepDustPropose(actionId, to, token, amount, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes a proposed dust sweep action after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param token Address of the token to sweep.
    /// @param to Address to receive the swept tokens.
    /// @param amount Amount of tokens to sweep.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Only callable by the Vault. Reverts if the action is not proposed, timelock is not expired, or parameters mismatch. Deletes the action from pendingSweepDust.
    function executeSweepDust(
        bytes32 actionId,
        address token,
        address to,
        uint256 amount
    ) external onlyVault returns (bool) {
        PendingSweepDust memory action = pendingSweepDust[actionId];
        if (action.executableAfter == 0) revert Error.ActionNotProposed();
        if (block.timestamp < action.executableAfter) revert  Error.TimelockNotExpired();
        if (action.key != keccak256("SWEEP_DUST")) revert  Error.InvalidKey();
        if (action.token != token) revert  Error.TokenMismatch();
        if (action.to != to) revert Error.RecipientMismatch();
        if (action.amount != amount) revert Error.AmountMismatch();
        
        delete pendingSweepDust[actionId];
        return true;
    }

    /// @notice Proposes setting a new WalletRouter address for the Vault.
    /// @param _walletAddress Proposed new WalletRouter address.
    /// @param key Unique identifier for the action.
    /// @dev Only callable by the Vault. Reverts if the action is already proposed. Emits SetWalletRouterPropose event.
    function proposeSetWalletRouter(address _walletAddress, bytes32 key) external onlyVault {
        bytes32 actionId = keccak256(abi.encode(key, _walletAddress, block.timestamp));
        if (pendingVault[actionId].executableAfter != 0) revert Error.ActionAlreadyProposed();
        pendingVault[actionId] = PendingVault({
            key: key,
            target: _walletAddress,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit SetWalletRouterPropose(actionId, _walletAddress, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes a proposed WalletRouter address change after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param _walletRouter New WalletRouter address.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Only callable by the Vault. Reverts if the action is not proposed, timelock is not expired, or WalletRouter address mismatches. Deletes the action from pendingVault.
    function executeSetWalletRouter(bytes32 actionId, address _walletRouter) external onlyVault returns (bool) {
        PendingVault memory action = pendingVault[actionId];
        if (action.executableAfter == 0) revert Error.ActionNotProposed();
        if (block.timestamp < action.executableAfter) revert  Error.TimelockNotExpired();
        if (action.key != keccak256("SET_WALLETROUTER")) revert  Error.InvalidKey();
        if (action.target != _walletRouter) revert  Error.WalletRouterMismatch();
        delete pendingVault[actionId];
        return true;
    }

    /// @notice Proposes a fund recovery action from the Vault.
    /// @param token Address of the token to recover.
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens to recover.
    /// @param key Unique identifier for the action.
    /// @dev Only callable by the Vault. Reverts if the action is already proposed. Emits RecoverFundsPropose event.
    function proposeRecoverFunds(address token, address recipient, uint256 amount, bytes32 key) external onlyVault {
        bytes32 actionId = keccak256(abi.encode(key, token, recipient, amount, block.timestamp));
        if (pendingRecoverFunds[actionId].executableAfter != 0) revert Error.ActionAlreadyProposed();
        pendingRecoverFunds[actionId] = PendingRecoverFunds({
            key: key,
            token: token,
            recipient: recipient,
            amount: amount,
            executableAfter: block.timestamp + MIN_TIMELOCK_DELAY
        });
        emit RecoverFundsPropose(actionId, token, recipient, amount, block.timestamp + MIN_TIMELOCK_DELAY);
    }

    /// @notice Executes a proposed fund recovery action after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param token Address of the token to recover.
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens to recover.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Only callable by the Vault. Reverts if the action is not proposed, timelock is not expired, or parameters mismatch. Deletes the action from pendingRecoverFunds.
    function executeRecoverFunds(bytes32 actionId, address token, address recipient, uint256 amount) external onlyVault returns (bool) {
        PendingRecoverFunds memory action = pendingRecoverFunds[actionId];
        if (action.executableAfter == 0) revert Error.ActionNotProposed();
        if (block.timestamp < action.executableAfter) revert  Error.TimelockNotExpired();
        if (action.key != keccak256("RECOVER_FUNDS")) revert  Error.InvalidKey();
        if (action.token != token) revert Error.TokenMismatch();
        if (action.recipient != recipient) revert Error.RecipientMismatch();
        if (action.amount != amount) revert  Error.AmountMismatch(); 
        delete pendingRecoverFunds[actionId];
        return true;
    }

    /// @notice Sets the timelock delay period.
    /// @param daysCount Number of days for the new delay.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Reverts if daysCount is zero. Emits TimelockDelayChanged event.
    function setTimelock(uint256 daysCount) external onlyRouterAdmin {
        if (daysCount ==  0) revert  Error.DelayMustBeAtLeastOneDay();
        uint256 newDelay = daysCount * 1 days;
        MIN_TIMELOCK_DELAY = newDelay;
        emit TimelockDelayChanged(MIN_TIMELOCK_DELAY, newDelay);
    }
}
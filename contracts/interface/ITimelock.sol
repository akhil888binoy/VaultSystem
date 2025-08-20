// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ITimelock
/// @notice Interface for managing delayed execution of sensitive Vault operations, such as setting WalletRouter, recovering funds, and sweeping dust.
/// @dev Defines functions for proposing and executing timelocked actions, with implementations expected to enforce a delay and emit events for transparency.
interface ITimelock {

    /// @notice Proposes setting a new WalletRouter address for the Vault.
    /// @param _walletRouter Proposed new WalletRouter address.
    /// @param key Unique identifier for the action.
    /// @dev Implementations should restrict to authorized callers (e.g., VAULT_ADMIN_ROLE), revert if action is already proposed, and emit a SetWalletRouterPropose event.
    function proposeSetWalletRouter(address _walletRouter, bytes32 key) external;

    /// @notice Executes setting a new WalletRouter address after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param _walletRouter New WalletRouter address.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Implementations should restrict to authorized callers, revert if timelock is not expired or parameters mismatch, and delete the pending action.
    function executeSetWalletRouter(bytes32 actionId, address _walletRouter) external returns (bool);

    /// @notice Proposes recovering funds from the Vault.
    /// @param token Token address to recover (address(0) for ETH).
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens or ETH to recover.
    /// @param key Unique identifier for the action.
    /// @dev Implementations should restrict to authorized callers (e.g., VAULT_ADMIN_ROLE), revert if action is already proposed, and emit a RecoverFundsPropose event.
    function proposeRecoverFunds(address token, address recipient, uint256 amount, bytes32 key) external;

    /// @notice Executes recovering funds from the Vault after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param token Token address to recover (address(0) for ETH).
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens or ETH to recover.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Implementations should restrict to authorized callers, revert if timelock is not expired or parameters mismatch, and delete the pending action.
    function executeRecoverFunds(bytes32 actionId, address token, address recipient, uint256 amount) external returns (bool);

    /// @notice Proposes sweeping untracked (dust) tokens or ETH from the Vault.
    /// @param token Token address to sweep (address(0) for ETH).
    /// @param to Address to receive the swept funds.
    /// @param amount Amount of tokens or ETH to sweep.
    /// @param key Unique identifier for the action.
    /// @dev Implementations should restrict to authorized callers (e.g., VAULT_ADMIN_ROLE), revert if action is already proposed, and emit a SweepDustPropose event.
    function proposeSweepDust(address token, address to, uint256 amount, bytes32 key) external;

    /// @notice Executes sweeping untracked (dust) tokens or ETH after timelock validation.
    /// @param actionId Unique identifier of the proposed action.
    /// @param token Token address to sweep (address(0) for ETH).
    /// @param to Address to receive the swept funds.
    /// @param amount Amount of tokens or ETH to sweep.
    /// @return True if the action is successfully validated and marked for execution.
    /// @dev Implementations should restrict to authorized callers, revert if timelock is not expired or parameters mismatch, and delete the pending action.
    function executeSweepDust(bytes32 actionId, address token, address to, uint256 amount) external returns (bool);
}
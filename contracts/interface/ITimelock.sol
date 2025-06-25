// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ITimelock
/// @notice Interface for timelock operations to enforce delayed execution of sensitive actions.
/// @dev Defines functions for proposing and executing timelocked actions.
interface ITimelock {
    /// @notice Proposes setting a new vault address.
    /// @param key The action identifier.
    /// @param _newvault The proposed new vault address.
    /// @param caller The address proposing the action.
    function proposeSetVault(bytes32 key, address _newvault, address caller) external;

    /// @notice Executes the setting of a new vault address.
    /// @param actionId The identifier of the proposed action.
    /// @param vault The new vault address.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    function executeSetVault(bytes32 actionId, address vault, address caller) external returns (bool);

    /// @notice Proposes adding a supported token.
    /// @param token The token address to add.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    function proposeAddToken(address token, bytes32 key, address caller) external;

    /// @notice Executes the addition of a supported token.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to add.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    function executeAddToken(bytes32 actionId, address token, address caller) external returns (bool);

    /// @notice Proposes removing a supported token.
    /// @param token The token address to remove.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    function proposeRemoveToken(address token, bytes32 key, address caller) external;

    /// @notice Executes the removal of a supported token.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to remove.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    function executeRemoveToken(bytes32 actionId, address token, address caller) external returns (bool);

    /// @notice Proposes setting a new WalletRouter address.
    /// @param _walletRouter The proposed new WalletRouter address.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    function proposeSetWalletRouter(address _walletRouter, bytes32 key, address caller) external;

    /// @notice Executes the setting of a new WalletRouter address.
    /// @param actionId The identifier of the proposed action.
    /// @param _walletRouter The new WalletRouter address.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    function executeSetWalletRouter(bytes32 actionId, address _walletRouter, address caller) external returns (bool);

    /// @notice Proposes recovering funds from the vault.
    /// @param token The token address to recover.
    /// @param recipient The address to receive the recovered funds.
    /// @param amount The amount to recover.
    /// @param key The action identifier.
    /// @param caller The address proposing the action.
    function proposeRecoverFunds(address token, address recipient, uint256 amount, bytes32 key, address caller) external;

    /// @notice Executes the recovery of funds.
    /// @param actionId The identifier of the proposed action.
    /// @param token The token address to recover.
    /// @param caller The address executing the action.
    /// @return True if the execution is successful.
    function executeRecoverFunds(bytes32 actionId, address token, address caller) external returns (bool);
}
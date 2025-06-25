// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IVault
/// @notice Interface for vault operations with explicit visibility.
/// @dev Defines functions for managing deposits, withdrawals, and supported tokens.
interface IVault {
    /// @notice Initializes the vault with required contract addresses.
    /// @param _roleManager Address of the RoleManager contract.
    /// @param _walletRouter Address of the WalletRouter contract.
    /// @param _timelock Address of the Timelock contract.
    function initialize(address _roleManager, address _walletRouter, address _timelock) external;

    /// @notice Handles deposits of tokens or ETH.
    /// @param user The user making the deposit.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to deposit.
    function handleDeposit(address user, address token, uint256 amount) external payable;

    /// @notice Handles withdrawals of tokens or ETH.
    /// @param recipient The address to receive the funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to withdraw.
    function handleWithdrawal(address recipient, address token, uint256 amount) external;

    /// @notice Returns the total deposits for a token.
    /// @param token The token address (address(0) for ETH).
    /// @return The total deposited amount.
    function totalDeposits(address token) external view returns (uint256);

    /// @notice Checks if a token is supported.
    /// @param token The token address (address(0) for ETH).
    /// @return True if the token is supported, false otherwise.
    function isSupportedToken(address token) external view returns (bool);

    /// @notice Adds a supported token.
    /// @param token The token address to add.
    /// @param actionId The identifier of the timelocked action.
    function addSupportedToken(address token, bytes32 actionId) external;

    /// @notice Removes a supported token.
    /// @param token The token address to remove.
    /// @param actionId The identifier of the timelocked action.
    function removeSupportedToken(address token, bytes32 actionId) external;
}
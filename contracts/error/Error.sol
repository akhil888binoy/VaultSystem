// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Error
/// @notice Library defining custom errors for gas-efficient revert conditions in Vault and Timelock contracts.
/// @dev Used across contracts to handle specific failure cases with descriptive error messages.
library Error {

    /// @notice Thrown when an action is proposed that already exists in the Timelock.
    /// @dev Used in Timelock proposal functions like proposeSetWalletRouter, proposeRecoverFunds, or proposeSweepDust.
    error ActionAlreadyProposed();

    /// @notice Thrown when attempting to execute a Timelock action that was not proposed.
    /// @dev Used in Timelock execution functions like executeSetWalletRouter, executeRecoverFunds, or executeSweepDust.
    error ActionNotProposed();

    /// @notice Thrown when the provided amount does not match the proposed action amount in Timelock.
    /// @dev Used in Timelock execution functions like executeRecoverFunds or executeSweepDust.
    error AmountMismatch();

    /// @notice Thrown when the caller lacks the VAULT_ADMIN_ROLE.
    /// @dev Used in Vault functions requiring VAULT_ADMIN_ROLE, such as addSupportedToken, setWalletRouter, or pause.
    error CallerLacksVaultAdminRole();

    /// @notice Thrown when attempting to remove a supported token with non-zero tracked deposits.
    /// @dev Used in Vault's removeSupportedToken function.
    error CannotRemoveTokenWithDeposits();

    /// @notice Thrown when attempting to sweep a supported token with non-zero tracked deposits.
    /// @dev Used in Vault's sweepDust function to prevent sweeping tracked deposits.
    error CannotSweepTokenWithDeposit();

    /// @notice Thrown when the timelock delay is set to less than one day.
    /// @dev Used in Timelock's setTimelock function.
    error DelayMustBeAtLeastOneDay();

    /// @notice Thrown when the ETH amount sent does not match the expected amount for a deposit.
    /// @dev Used in Vault's handleDeposit function for ETH deposits.
    error ETHAmountMismatch();

    /// @notice Thrown when ETH is sent during a token transfer operation.
    /// @dev Used in Vault's handleDeposit to prevent ETH being sent with ERC20 token deposits.
    error ETHSentWithTokenTransfer();

    /// @notice Thrown when a Timelock execution function fails validation.
    /// @dev Used in Vault's sweepDust, setWalletRouter, or recoverFunds when Timelock execution fails.
    error ExecutionFailed();

    /// @notice Thrown when a provided implementation address is not a contract.
    /// @dev Used in Vault's _authorizeUpgrade function for UUPS upgrades.
    error ImplementationIsNotAContract();

    /// @notice Thrown when the Vault's ETH balance is insufficient for a withdrawal or recovery.
    /// @dev Used in Vault's handleWithdrawal or recoverFunds for ETH operations.
    error InsufficientVaultETHBalance();

    /// @notice Thrown when the Vault's token balance is insufficient for a withdrawal or recovery.
    /// @dev Used in Vault's handleWithdrawal or recoverFunds for ERC20 token operations.
    error InsufficientVaultTokenBalance();

    /// @notice Thrown when the tracked deposits are insufficient for a withdrawal or recovery.
    /// @dev Used in Vault's handleWithdrawal or recoverFunds when totalDeposits is too low.
    error InsufficientTrackedDeposits();

    /// @notice Thrown when an invalid WalletRouter address (e.g., zero address) is provided.
    /// @dev Used in Vault's initialize, proposeSetWalletRouter, or Timelock's setVault.
    error InvalidWalletRouter();

    /// @notice Thrown when an invalid account address (e.g., zero address) is provided.
    /// @dev Used in contracts for general address validation (e.g., user or recipient addresses).
    error InvalidAccount();

    /// @notice Thrown when an invalid admin address (e.g., zero address) is provided.
    /// @dev Used in contracts for admin-related address validation.
    error InvalidAdminAddress();

    /// @notice Thrown when an invalid amount (e.g., zero) is provided for an operation.
    /// @dev Used in Vault's sweepDust or proposeSweepDust functions.
    error InvalidAmount();

    /// @notice Thrown when an invalid implementation address (e.g., zero address) is provided for a UUPS upgrade.
    /// @dev Used in Vault's _authorizeUpgrade function.
    error InvalidImplementationAddress();

    /// @notice Thrown when the provided key does not match the expected action key in Timelock.
    /// @dev Used in Timelock execution functions like executeSetWalletRouter, executeRecoverFunds, or executeSweepDust.
    error InvalidKey();

    /// @notice Thrown when an invalid recipient address (e.g., zero address) is provided.
    /// @dev Used in Vault's proposeRecoverFunds, proposeSweepDust, or sweepDust functions.
    error InvalidRecipient();

    /// @notice Thrown when an invalid RoleManager address (e.g., zero address) is provided.
    /// @dev Used in Vault's initialize or Timelock's constructor.
    error InvalidRoleManager();

    /// @notice Thrown when an invalid Timelock address (e.g., zero address) is provided.
    /// @dev Used in Vault's initialize function.
    error InvalidTimelock();

    /// @notice Thrown when an invalid Vault address (e.g., zero address) is provided.
    /// @dev Used in Timelock's setVault function.
    error InvalidVaultAddress();

    /// @notice Thrown when no transfer is proposed for a given action.
    /// @dev Potentially used in transfer-related functions (not explicitly used in provided contracts).
    error NoTransferProposed();

    /// @notice Thrown when the caller is not the WalletRouter contract.
    /// @dev Used in Vault's onlyWalletRouter modifier for functions like handleDeposit or handleWithdrawal.
    error NotWalletRouter();

    /// @notice Thrown when the caller is not an operator.
    /// @dev Potentially used in contracts with operator roles (not explicitly used in provided contracts).
    error NotOperator();

    /// @notice Thrown when the caller lacks the ROUTER_ADMIN_ROLE.
    /// @dev Used in Timelock's onlyRouterAdmin modifier for functions like setVault or setTimelock.
    error NotRouterAdmin();

    /// @notice Thrown when an old admin address lacks the DEFAULT_ADMIN_ROLE during a role transition.
    /// @dev Used in role management functions (e.g., in RoleManager) when attempting to revoke or transfer admin privileges from an address that no longer holds DEFAULT_ADMIN_ROLE.
    error OldAdminLacksDefaultAdminRole();

    /// @notice Thrown when a function restricted to ROUTER_ADMIN_ROLE is called by an unauthorized account.
    /// @dev Used in Timelock's onlyRouterAdmin modifier as an alternative to NotRouterAdmin.
    error OnlyRouterAdmin();

    /// @notice Thrown when a function restricted to the Vault contract is called by another address.
    /// @dev Used in Timelock's onlyVault modifier for functions like proposeSetWalletRouter or proposeRecoverFunds.
    error OnlyVault();

    /// @notice Thrown when fund recovery execution fails in Timelock.
    /// @dev Used in Vault's recoverFunds function when Timelock's executeRecoverFunds fails.
    error RecoverFundsNotExecuted();

    /// @notice Thrown when the recipient address does not match the proposed action recipient in Timelock.
    /// @dev Used in Timelock's executeRecoverFunds or executeSweepDust functions.
    error RecipientMismatch();

    /// @notice Thrown when WalletRouter setting execution fails in Timelock.
    /// @dev Used in Vault's setWalletRouter function when Timelock's executeSetWalletRouter fails.
    error SetWalletRouterNotExecuted();

    /// @notice Thrown when attempting to execute a Timelock action before the delay period expires.
    /// @dev Used in Timelock execution functions like executeSetWalletRouter, executeRecoverFunds, or executeSweepDust.
    error TimelockNotExpired();

    /// @notice Thrown when attempting to add a token that is already supported.
    /// @dev Used in Vault's addSupportedToken function.
    error TokenAlreadySupported();

    /// @notice Thrown when a provided token address is not a contract.
    /// @dev Used in Vault's addSupportedToken or sweepDust for non-ETH tokens.
    error TokenIsNotAContract();

    /// @notice Thrown when the provided token does not match the proposed action token in Timelock.
    /// @dev Used in Timelock's executeRecoverFunds or executeSweepDust functions.
    error TokenMismatch();

    /// @notice Thrown when an operation involves an unsupported token.
    /// @dev Used in Vault's onlySupportedToken modifier for functions like handleDeposit or handleWithdrawal.
    error TokenNotSupported();

    /// @notice Thrown when an ERC20 token transfer fails.
    /// @dev Used in Vault's handleWithdrawal or recoverFunds when safeTransfer fails.
    error TokenTransferFailed();

    /// @notice Thrown when attempting to remove a token with a non-zero ETH balance in the Vault.
    /// @dev Used in Vault's removeSupportedToken for ETH (address(0)).
    error VaultHasETHBalance();

    /// @notice Thrown when attempting to remove a token with a non-zero token balance in the Vault.
    /// @dev Used in Vault's removeSupportedToken for ERC20 tokens.
    error VaultHasTokenBalance();

    /// @notice Thrown when the Vault address is not set.
    /// @dev Potentially used in contracts requiring a valid Vault address (not explicitly used in provided contracts).
    error VaultNotSet();

    /// @notice Thrown when the provided WalletRouter address is not a contract.
    /// @dev Used in Vault's initialize function.
    error WalletRouterIsNotAContract();

    /// @notice Thrown when the provided WalletRouter does not match the proposed action WalletRouter in Timelock.
    /// @dev Used in Timelock's executeSetWalletRouter function.
    error WalletRouterMismatch();
}
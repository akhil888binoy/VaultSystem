// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IVault.sol";
import "../interface/IRoleManager.sol";
import "../interface/ITimelock.sol";

/// @title WalletRouter
/// @notice Routes deposits and withdrawals to a vault with role-based access, pausability, and enhanced event tracking.
/// @dev Inherits ReentrancyGuard for protection against reentrancy attacks and Pausable for emergency stops.
contract WalletRouter is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Address of the RoleManager contract for access control.
    IRoleManager public roleManager;

    /// @notice Address of the Vault contract where funds are routed.
    IVault public vault;

    /// @notice Address of the Timelock contract for delayed execution of sensitive operations.
    ITimelock public timelock;

    /// @notice Constant for the SET_VAULT action identifier used in timelock proposals.
    bytes32 public constant SET_VAULT = keccak256("SET_VAULT");

    /// @notice Emitted when a deposit is successfully processed.
    /// @param user The address of the user depositing funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount deposited.
    /// @param timestamp The timestamp of the deposit.
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 timestamp);

    /// @notice Emitted when a withdrawal is successfully processed.
    /// @param recipient The address receiving the withdrawn funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount withdrawn.
    /// @param timestamp The timestamp of the withdrawal.
    event Withdrawal(address indexed recipient, address indexed token, uint256 amount, uint256 timestamp);

    /// @notice Emitted when the vault address is updated.
    /// @param vault The new vault address.
    event VaultSet(address indexed vault);

    /// @notice Initializes the contract with RoleManager and Timelock addresses.
    /// @param _roleManager Address of the RoleManager contract.
    /// @param _timelock Address of the Timelock contract.
    /// @dev Reverts if either address is zero.
    constructor(address _roleManager, address _timelock) {
        require(_roleManager != address(0), "Invalid RoleManager");
        require(_timelock != address(0), "Invalid Timelock");
        roleManager = IRoleManager(_roleManager);
        timelock = ITimelock(_timelock);
    }

    /// @notice Restricts function access to accounts with the OPERATOR_ROLE.
    /// @dev Reverts if the caller does not have the OPERATOR_ROLE.
    modifier onlyOperator() {
        require(roleManager.hasRole(roleManager.OPERATOR_ROLE(), msg.sender), "Not operator");
        _;
    }

    /// @notice Restricts function access to accounts with the ROUTER_ADMIN_ROLE.
    /// @dev Reverts if the caller does not have the ROUTER_ADMIN_ROLE.
    modifier onlyRouterAdmin() {
        require(roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), msg.sender), "Not router admin");
        _;
    }

    /// @notice Proposes setting a new vault address via the timelock.
    /// @param _vault The proposed new vault address.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Reverts if the vault address is zero.
    function proposeSetVault(address _vault) external onlyRouterAdmin {
        require(_vault != address(0), "Invalid vault address");
        timelock.proposeSetVault(SET_VAULT, _vault, msg.sender);
    }

    /// @notice Executes the setting of a new vault address after timelock validation.
    /// @param _vault The new vault address to set.
    /// @param actionId The identifier of the proposed action.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Emits VaultSet event on success.
    function setVault(address _vault, bytes32 actionId) external onlyRouterAdmin {
        require(timelock.executeSetVault(actionId, _vault, msg.sender), "Cannot execute setVault");
        vault = IVault(_vault);
        emit VaultSet(_vault);
    }

    /// @notice Pauses deposit and withdrawal operations.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Inherits from Pausable.
    function pause() external onlyRouterAdmin {
        _pause();
    }

    /// @notice Unpauses deposit and withdrawal operations.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Inherits from Pausable.
    function unpause() external onlyRouterAdmin {
        _unpause();
    }

    /// @notice Deposits tokens or ETH into the vault.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to deposit.
    /// @dev Reverts if paused, amount is zero, vault is not set, or token is not supported. Emits Deposit event.
    function deposit(address token, uint256 amount) external payable nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(address(vault) != address(0), "Vault not set");
        require(vault.isSupportedToken(token), "Token not supported");

        if (token == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
            vault.handleDeposit{value: amount}(msg.sender, token, amount);
        } else {
            uint256 balanceBefore = IERC20(token).balanceOf(address(vault));
            IERC20(token).safeTransferFrom(msg.sender, address(vault), amount);
            uint256 balanceAfter = IERC20(token).balanceOf(address(vault));
            uint256 receivedAmount = balanceAfter - balanceBefore;
            require(receivedAmount >= amount, "Token transfer failed");
            vault.handleDeposit(msg.sender, token, receivedAmount);
        }
        emit Deposit(msg.sender, token, amount, block.timestamp);
    }

    /// @notice Withdraws tokens or ETH from the vault.
    /// @param recipient The address to receive the funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to withdraw.
    /// @dev Only callable by OPERATOR_ROLE. Reverts if paused, amount is zero, vault is not set, or token is not supported. Emits Withdrawal event.
    function withdraw(address recipient, address token, uint256 amount) external nonReentrant onlyOperator whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(address(vault) != address(0), "Vault not set");
        require(vault.isSupportedToken(token), "Token not supported");
        vault.handleWithdrawal(recipient, token, amount);
        emit Withdrawal(recipient, token, amount, block.timestamp);
    }
}
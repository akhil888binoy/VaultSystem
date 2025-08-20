// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interface/IVault.sol";
import "../interface/IRoleManager.sol";
import "../interface/ITimelock.sol";
import "../error/Error.sol";

/// @title WalletRouter
/// @notice Routes deposits and withdrawals to a vault with role-based access, pausability, and enhanced event tracking.
/// @dev Inherits ReentrancyGuard for protection against reentrancy attacks and Pausable for emergency stops.
contract WalletRouter is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address payable;

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
        if(_roleManager == address(0)) revert Error.InvalidRoleManager();
        if (_timelock == address(0)) revert Error.InvalidTimelock();
        roleManager = IRoleManager(_roleManager);
        timelock = ITimelock(_timelock);
    }

    /// @notice Restricts function access to accounts with the OPERATOR_ROLE.
    /// @dev Reverts if the caller does not have the OPERATOR_ROLE.
    modifier onlyOperator() {
        if (!roleManager.hasRole(roleManager.OPERATOR_ROLE(), msg.sender)) 
            revert Error.NotOperator();
        _;
    }
    

    /// @notice Restricts function access to accounts with the ROUTER_ADMIN_ROLE.
    /// @dev Reverts if the caller does not have the ROUTER_ADMIN_ROLE.
    modifier onlyRouterAdmin() {
        if (!roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), msg.sender)) 
            revert Error.NotRouterAdmin();
        _;
    }


    /// @notice Executes the setting of a new vault address.
    /// @param _vault The new vault address to set.
    /// @dev Only callable by ROUTER_ADMIN_ROLE. Emits VaultSet event on success.
    function setVault(address _vault) external onlyRouterAdmin whenNotPaused {
        if (_vault == address(0)) revert Error.InvalidVaultAddress();
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
        if (amount == 0) revert Error.InvalidAmount();
        if (address(vault) == address(0)) revert  Error.VaultNotSet();
        if (!vault.isSupportedToken(token)) revert Error.TokenNotSupported();

        if (token == address(0)) {
            if (msg.value != amount) revert Error.ETHAmountMismatch();
            payable(address(vault)).sendValue(amount); // Send ETH to Vault
            vault.handleDeposit(msg.sender, token, amount); // Record deposit
            emit Deposit(msg.sender, token, msg.value, block.timestamp);
        } else {
            if (msg.value != 0) revert  Error.ETHSentWithTokenTransfer();
            uint256 balanceBefore = IERC20(token).balanceOf(address(vault));
            IERC20(token).safeTransferFrom(msg.sender, address(vault), amount);
            uint256 balanceAfter = IERC20(token).balanceOf(address(vault));
            uint256 receivedAmount = balanceAfter - balanceBefore;
            if (receivedAmount == 0) revert Error.TokenTransferFailed();
            vault.handleDeposit(msg.sender, token, receivedAmount);
            emit Deposit(msg.sender, token, receivedAmount, block.timestamp);
        }
    }

    /// @notice Withdraws tokens or ETH from the vault.
    /// @param recipient The address to receive the funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to withdraw.
    /// @dev Only callable by OPERATOR_ROLE. Reverts if paused, amount is zero, vault is not set, or token is not supported. Emits Withdrawal event.
    function withdraw(address recipient, address token, uint256 amount) external nonReentrant onlyOperator whenNotPaused {
        if (amount == 0)  revert Error.InvalidAmount();
        if (address(vault) == address(0)) revert  Error.VaultNotSet();
        if (!vault.isSupportedToken(token)) revert  Error.TokenNotSupported();
        vault.handleWithdrawal(recipient, token, amount);
        emit Withdrawal(recipient, token, amount, block.timestamp);
    }
}



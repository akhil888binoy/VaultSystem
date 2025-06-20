// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IVault.sol";
import "../interface/IRoleManager.sol";

contract WalletRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRoleManager public roleManager;
    IVault public vault;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed recipient, address indexed token, uint256 amount);

    constructor(address _roleManager) {
        roleManager = IRoleManager(_roleManager);
    }

    modifier onlyOperator() {
        require(roleManager.hasRole(roleManager.OPERATOR_ROLE(), msg.sender), "Not operator");
        _;
    }

    function setVault(address _vault) external {
        require(roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), msg.sender), "Not admin");
        vault = IVault(_vault);
    }

    function deposit(address token, uint256 amount) external payable nonReentrant {
        require(amount > 0, "Invalid amount");
        require(address(vault) != address(0), "Vault not set");
        require(vault.isSupportedToken(token), "Token not supported");
        
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
            vault.handleDeposit{value: amount}(msg.sender, token, amount);
        } else {
            require(msg.value == 0, "ETH not allowed for ERC20 deposit");
            IERC20(token).safeTransferFrom(msg.sender, address(vault), amount);
            vault.handleDeposit(msg.sender, token, amount);
        }
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address recipient, address token, uint256 amount) external nonReentrant onlyOperator {
        require(amount > 0, "Invalid amount");
        require(address(vault) != address(0), "Vault not set");
        require(vault.isSupportedToken(token), "Token not supported");
        
        if (token != address(0)) {
            require(IERC20(token).balanceOf(address(vault)) >= amount, "Insufficient Vault balance");
        }
        vault.handleWithdrawal(recipient, token, amount);
        emit Withdrawal(recipient, token, amount);
    }
}

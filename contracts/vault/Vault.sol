// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interface/IRoleManager.sol";

contract Vault is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IRoleManager public roleManager;
    address public walletRouter;
    mapping(address => bool) public supportedTokens; // Token address => isSupported (address(0) for ETH)
    mapping(address => uint256) public totalDeposits; // Token address => total deposits

    event DepositProcessed(address indexed user, address indexed token, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, address indexed token, uint256 amount);
    event TokenSupportAdded(address indexed token);
    event TokenSupportRemoved(address indexed token);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        address _roleManager,
        address _initialAdmin,
        address _walletRouter
    ) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        require(_roleManager != address(0), "Invalid RoleManager");
        require(_initialAdmin != address(0), "Invalid admin");
        require(_walletRouter != address(0), "Invalid WalletRouter");

        roleManager = IRoleManager(_roleManager);
        walletRouter = _walletRouter;
        
        roleManager.grantRole(roleManager.VAULT_ADMIN_ROLE(), _initialAdmin);
        supportedTokens[address(0)] = true; // Enable ETH by default
        emit TokenSupportAdded(address(0));
    }

    modifier onlyAdmin() {
        require(
            roleManager.hasRole(roleManager.VAULT_ADMIN_ROLE(), msg.sender),
            "Not admin"
        );
        _;
    }

    modifier onlyWalletRouter() {
        require(msg.sender == walletRouter, "Not WalletRouter");
        _;
    }

    modifier onlySupportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    function isSupportedToken(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    function handleDeposit(address user, address token, uint256 amount) external payable onlyWalletRouter onlySupportedToken(token) {
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH not allowed for ERC20 deposit");
        }
        totalDeposits[token] += amount;
        emit DepositProcessed(user, token, amount);
    }

    function handleWithdrawal(address recipient, address token, uint256 amount) external onlyWalletRouter onlySupportedToken(token) {
        totalDeposits[token] -= amount;
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20Upgradeable(token).safeTransfer(recipient, amount);
        }
        emit WithdrawalProcessed(recipient, token, amount);
    }

    function addSupportedToken(address token) external onlyAdmin {
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
        emit TokenSupportAdded(token);
    }

    function removeSupportedToken(address token) external onlyAdmin {
        require(supportedTokens[token], "Token not supported");
        require(totalDeposits[token] == 0, "Cannot remove token with deposits");
        supportedTokens[token] = false;
        emit TokenSupportRemoved(token);
    }

    function setWalletRouter(address _walletRouter) external onlyAdmin {
        require(_walletRouter != address(0), "Invalid WalletRouter");
        walletRouter = _walletRouter;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}

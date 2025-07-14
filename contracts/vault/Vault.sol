// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "../interface/IRoleManager.sol";
import "../interface/ITimelock.sol";

/// @title Vault
/// @notice Manages deposits and withdrawals of supported tokens, with upgradeability and access control.
/// @dev Uses UUPS proxy pattern for upgradeability and integrates with RoleManager and Timelock for security.
contract Vault is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;

    /// @notice Address of the RoleManager contract for access control.
    IRoleManager public roleManager;

    /// @notice Address of the Timelock contract for delayed execution of sensitive operations.
    ITimelock public timelock;

    /// @notice Address of the WalletRouter contract that routes deposits and withdrawals.
    address public walletRouter;

    /// @notice Mapping of token addresses to their support status (address(0) for ETH).
    mapping(address => bool) public supportedTokens;

    /// @notice Mapping of token addresses to their total deposited amounts.
    mapping(address => uint256) public totalDeposits;

    /// @notice Emitted when a deposit is processed.
    /// @param user The address of the user depositing funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount deposited.
    event DepositProcessed(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when a withdrawal is processed.
    /// @param recipient The address receiving the withdrawn funds.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount withdrawn.
    event WithdrawalProcessed(address indexed recipient, address indexed token, uint256 amount);

    /// @notice Emitted when a token is added to the supported tokens list.
    /// @param token The token address added.
    event TokenSupportAdded(address indexed token);

    /// @notice Emitted when a token is removed from the supported tokens list.
    /// @param token The token address removed.
    event TokenSupportRemoved(address indexed token);

    /// @notice Emitted when the WalletRouter address is updated.
    /// @param walletRouter The new WalletRouter address.
    event WalletRouterSet(address indexed walletRouter);

    /// @notice Emitted when funds are recovered from the vault.
    /// @param token The token address recovered (address(0) for ETH).
    /// @param recipient The address receiving the recovered funds.
    /// @param amount The amount recovered.
    event FundsRecovered(address indexed token, address indexed recipient, uint256 amount);

    /// @notice Constant for the ADD_TOKEN action identifier used in timelock proposals.
    bytes32 public constant ADD_TOKEN = keccak256("ADD_TOKEN");

    /// @notice Constant for the REMOVE_TOKEN action identifier used in timelock proposals.
    bytes32 public constant REMOVE_TOKEN = keccak256("REMOVE_TOKEN");

    /// @notice Constant for the SET_WALLETROUTER action identifier used in timelock proposals.
    bytes32 public constant SET_WALLETROUTER = keccak256("SET_WALLETROUTER");

    /// @notice Constant for the RECOVER_FUNDS action identifier used in timelock proposals.
    bytes32 public constant RECOVER_FUNDS = keccak256("RECOVER_FUNDS");

    /// @notice Constructor to disable initialization of the implementation contract.
    /// @dev Prevents the implementation from being initialized directly.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /// @notice Initializes the vault with RoleManager, WalletRouter, and Timelock addresses.
    /// @param _roleManager Address of the RoleManager contract.
    /// @param _walletRouter Address of the WalletRouter contract.
    /// @param _timelock Address of the Timelock contract.
    /// @dev Reverts if any address is invalid or WalletRouter is not a contract. Enables ETH support by default.
    function initialize(address _roleManager, address _walletRouter, address _timelock) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_roleManager != address(0), "Invalid RoleManager");
        require(_walletRouter != address(0), "Invalid WalletRouter");
        require(_timelock != address(0), "Invalid Timelock");
        require(isContract(_walletRouter), "WalletRouter is not a contract");

        roleManager = IRoleManager(_roleManager);
        timelock = ITimelock(_timelock);
        walletRouter = _walletRouter;

        supportedTokens[address(0)] = true; // Enable ETH by default
        emit TokenSupportAdded(address(0));
    }

    /// @notice Restricts function access to accounts with the VAULT_ADMIN_ROLE.
    /// @dev Reverts if the caller does not have the VAULT_ADMIN_ROLE.
    modifier onlyVaultAdmin() {
        require(roleManager.hasRole(roleManager.VAULT_ADMIN_ROLE(), msg.sender), "Caller lacks VAULT_ADMIN_ROLE");
        _;
    }

    /// @notice Restricts function access to the WalletRouter contract.
    /// @dev Reverts if the caller is not the WalletRouter.
    modifier onlyWalletRouter() {
        require(msg.sender == walletRouter, "Not WalletRouter");
        _;
    }

    /// @notice Restricts function access to supported tokens only.
    /// @param token The token address to check (address(0) for ETH).
    /// @dev Reverts if the token is not supported.
    modifier onlySupportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    /// @notice Checks if a token is supported.
    /// @param token The token address to check (address(0) for ETH).
    /// @return True if the token is supported, false otherwise.
    function isSupportedToken(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    /// @notice Records a deposit of a supported token for a user.
    /// @param user The user making the deposit.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to deposit.
    /// @dev Only callable by WalletRouter. Reverts if paused, token is not supported, or incorrect ETH amount. Emits DepositProcessed event.
    function handleDeposit(address user, address token, uint256 amount) external payable onlyWalletRouter onlySupportedToken(token) whenNotPaused {
        totalDeposits[token] += amount;
        emit DepositProcessed(user, token, amount);
    }

    /// @notice Processes a withdrawal of a supported token to a recipient.
    /// @param recipient The recipient of the withdrawal.
    /// @param token The token address (address(0) for ETH).
    /// @param amount The amount to withdraw.
    /// @dev Only callable by WalletRouter. Reverts if paused, token is not supported, or insufficient balance. Emits WithdrawalProcessed event.
    function handleWithdrawal(address recipient, address token, uint256 amount) external onlyWalletRouter onlySupportedToken(token) whenNotPaused {
        require(totalDeposits[token] >= amount, "Insufficient tracked deposits");
        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient Vault ETH balance");
            payable(recipient).sendValue(amount);
        } else {
            require(IERC20Upgradeable(token).balanceOf(address(this)) >= amount, "Insufficient Vault token balance");
            IERC20Upgradeable(token).safeTransfer(recipient, amount);
        }
        totalDeposits[token] -= amount;
        emit WithdrawalProcessed(recipient, token, amount);
    }


    /// @notice Executes the addition of a supported token after timelock validation.
    /// @param token The token address to add.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Emits TokenSupportAdded event.
    function addSupportedToken(address token) external onlyVaultAdmin {
        require(!supportedTokens[token], "Token already supported");
        if (token != address(0)) {
            require(isContract(token), "Token is not a contract");
        }
        supportedTokens[token] = true;
        emit TokenSupportAdded(token);
    }


    /// @notice Executes the removal of a supported token after timelock validation.
    /// @param token The token address to remove.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Emits TokenSupportRemoved event.
    function removeSupportedToken(address token) external onlyVaultAdmin {
        require(supportedTokens[token], "Token not supported");
        require(totalDeposits[token] == 0, "Cannot remove token with deposits");
        if (token == address(0)) {
            require(address(this).balance == 0, "Vault has ETH balance");
        } else {
            require(IERC20Upgradeable(token).balanceOf(address(this)) == 0, "Vault has token balance");
        }
        supportedTokens[token] = false;
        emit TokenSupportRemoved(token);
    }

    /// @notice Proposes setting a new WalletRouter address via the timelock.
    /// @param _walletRouter The proposed new WalletRouter address.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if address is invalid.
    function proposeSetWalletRouter(address _walletRouter) external onlyVaultAdmin {
        require(_walletRouter != address(0), "Invalid WalletRouter");
        timelock.proposeSetWalletRouter(_walletRouter, SET_WALLETROUTER, msg.sender);
    }

    /// @notice Executes the setting of a new WalletRouter address after timelock validation.
    /// @param _walletRouter The new WalletRouter address.
    /// @param actionId The identifier of the proposed action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Emits WalletRouterSet event.
    function setWalletRouter(address _walletRouter, bytes32 actionId) external onlyVaultAdmin {
        require(timelock.executeSetWalletRouter(actionId, _walletRouter, msg.sender), "Set WalletRouter not executed");
        walletRouter = _walletRouter;
        emit WalletRouterSet(_walletRouter);
    }

    /// @notice Proposes recovering funds from the vault via the timelock.
    /// @param token The token address to recover (address(0) for ETH).
    /// @param recipient The address to receive the recovered funds.
    /// @param amount The amount to recover.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if recipient is invalid.
    function proposeRecoverFunds(address token, address recipient, uint256 amount) external onlyVaultAdmin {
        require(recipient != address(0), "Invalid recipient");
        timelock.proposeRecoverFunds(token, recipient, amount, keccak256("RECOVER_FUNDS"), msg.sender);
    }

    /// @notice Executes the recovery of funds after timelock validation.
    /// @param token The token address to recover (address(0) for ETH).
    /// @param recipient The address to receive the recovered funds.
    /// @param amount The amount to recover.
    /// @param actionId The identifier of the proposed action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Emits FundsRecovered event.
    function recoverFunds(address token, address recipient, uint256 amount, bytes32 actionId) external onlyVaultAdmin {
        require(timelock.executeRecoverFunds(actionId, token, msg.sender), "Recover funds not executed");
        require(totalDeposits[token] >= amount, "Insufficient tracked deposits");
        totalDeposits[token] -= amount;
        if (token == address(0)) {
            payable(recipient).sendValue(amount);
        } else {
            IERC20Upgradeable(token).safeTransfer(recipient, amount);
        }
        emit FundsRecovered(token, recipient, amount);
    }

    /// @notice Pauses deposits and withdrawals.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Inherits from PausableUpgradeable.
    function pause() external onlyVaultAdmin {
        _pause();
    }

    /// @notice Unpauses deposits and withdrawals.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Inherits from PausableUpgradeable.
    function unpause() external onlyVaultAdmin {
        _unpause();
    }

    /// @notice Authorizes a contract upgrade.
    /// @param newImplementation The new implementation address.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if address is invalid or not a contract.
    function _authorizeUpgrade(address newImplementation) internal onlyVaultAdmin override {
        require(newImplementation != address(0), "Invalid implementation address");
        require(isContract(newImplementation), "Implementation is not a contract");
    }

    /// @notice Checks if an address is a contract.
    /// @param addr The address to check.
    /// @return True if the address is a contract, false otherwise.
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    receive() external payable {}
}
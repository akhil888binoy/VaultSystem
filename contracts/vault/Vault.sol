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
import "../error/Error.sol";

/// @title Vault
/// @notice Manages deposits, withdrawals, and token support for ETH and ERC20 tokens with upgradeability, access control, and timelock integration.
/// @dev Implements UUPS proxy pattern, ReentrancyGuard, and Pausable from OpenZeppelin, integrating with RoleManager and Timelock for secure operations.
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

    /// @notice Emitted when a deposit is successfully processed.
    /// @param user Address of the user depositing funds.
    /// @param token Token address (address(0) for ETH).
    /// @param amount Amount of tokens or ETH deposited.
    event DepositProcessed(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when a withdrawal is successfully processed.
    /// @param recipient Address receiving the withdrawn funds.
    /// @param token Token address (address(0) for ETH).
    /// @param amount Amount of tokens or ETH withdrawn.
    event WithdrawalProcessed(address indexed recipient, address indexed token, uint256 amount);

    /// @notice Emitted when a token is added to the supported tokens list.
    /// @param token Token address added (address(0) for ETH).
    event TokenSupportAdded(address indexed token);

    /// @notice Emitted when a token is removed from the supported tokens list.
    /// @param token Token address removed (address(0) for ETH).
    event TokenSupportRemoved(address indexed token);

    /// @notice Emitted when the WalletRouter address is updated.
    /// @param walletRouter New WalletRouter address.
    event WalletRouterSet(address indexed walletRouter);

    /// @notice Emitted when funds are recovered from the Vault.
    /// @param token Token address recovered (address(0) for ETH).
    /// @param recipient Address receiving the recovered funds.
    /// @param amount Amount of tokens or ETH recovered.
    event FundsRecovered(address indexed token, address indexed recipient, uint256 amount);

    /// @notice Emitted when untracked (dust) tokens or ETH are swept from the Vault.
    /// @param token Token address swept (address(0) for ETH).
    /// @param to Address receiving the swept funds.
    /// @param amount Amount of tokens or ETH swept.
    event DustSwept(address indexed token, address indexed to, uint256 amount);

    /// @notice Constant for the SET_WALLETROUTER action identifier used in timelock proposals.
    bytes32 public constant SET_WALLETROUTER = keccak256("SET_WALLETROUTER");

    /// @notice Constant for the RECOVER_FUNDS action identifier used in timelock proposals.
    bytes32 public constant RECOVER_FUNDS = keccak256("RECOVER_FUNDS");

    /// @notice Constant for the SWEEP_DUST action identifier used in timelock proposals.
    bytes32 public constant SWEEP_DUST = keccak256("SWEEP_DUST");

    /// @notice Constructor to disable initialization of the implementation contract.
    /// @dev Prevents the implementation contract from being initialized directly, ensuring safety for UUPS proxy upgrades.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Vault with RoleManager, WalletRouter, and Timelock addresses.
    /// @param _roleManager Address of the RoleManager contract for access control.
    /// @param _walletRouter Address of the WalletRouter contract for routing deposits and withdrawals.
    /// @param _timelock Address of the Timelock contract for delayed operations.
    /// @dev Reverts if any address is zero or if WalletRouter is not a contract. Initializes UUPS, ReentrancyGuard, and Pausable. Enables ETH support by default. Emits TokenSupportAdded for ETH.
    function initialize(address _roleManager, address _walletRouter, address _timelock) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_roleManager == address(0)) revert Error.InvalidRoleManager();
        if (_walletRouter == address(0)) revert Error.InvalidWalletRouter();
        if (_timelock == address(0)) revert Error.InvalidTimelock();
        if (!isContract(_walletRouter)) revert  Error.WalletRouterIsNotAContract();

        roleManager = IRoleManager(_roleManager);
        timelock = ITimelock(_timelock);
        walletRouter = _walletRouter;

        supportedTokens[address(0)] = true; // Enable ETH by default
        emit TokenSupportAdded(address(0));
    }

    /// @notice Restricts function access to accounts with the VAULT_ADMIN_ROLE.
    /// @dev Reverts if the caller lacks the VAULT_ADMIN_ROLE from the RoleManager.
    modifier onlyVaultAdmin() {
        if (!roleManager.hasRole(roleManager.VAULT_ADMIN_ROLE(), msg.sender)) revert Error.CallerLacksVaultAdminRole();
        _;
    }

    /// @notice Restricts function access to the WalletRouter contract.
    /// @dev Reverts if the caller is not the current WalletRouter address.
    modifier onlyWalletRouter() {
        if (msg.sender != walletRouter) revert  Error.InvalidWalletRouter();
        _;
    }

    /// @notice Restricts function access to supported tokens only.
    /// @param token Token address to check (address(0) for ETH).
    /// @dev Reverts if the token is not supported in the supportedTokens mapping.
    modifier onlySupportedToken(address token) {
        if (!supportedTokens[token]) revert  Error.TokenNotSupported();
        _;
    }

    /// @notice Checks if a token is supported by the Vault.
    /// @param token Token address to check (address(0) for ETH).
    /// @return True if the token is supported, false otherwise.
    function isSupportedToken(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    /// @notice Records a deposit of a supported token or ETH for a user.
    /// @param user Address of the user depositing funds.
    /// @param token Token address (address(0) for ETH).
    /// @param amount Amount of tokens or ETH to deposit.
    /// @dev Only callable by WalletRouter when not paused. Reverts if token is not supported or contract is paused. Updates totalDeposits and emits DepositProcessed event.
    function handleDeposit(address user, address token, uint256 amount) external payable onlyWalletRouter onlySupportedToken(token) whenNotPaused {
        totalDeposits[token] += amount;
        emit DepositProcessed(user, token, amount);
    }

    /// @notice Processes a withdrawal of a supported token or ETH to a recipient.
    /// @param recipient Address to receive the withdrawn funds.
    /// @param token Token address (address(0) for ETH).
    /// @param amount Amount of tokens or ETH to withdraw.
    /// @dev Only callable by WalletRouter when not paused. Reverts if token is not supported, contract is paused, or insufficient balance. Updates totalDeposits and emits WithdrawalProcessed event.
    function handleWithdrawal(address recipient, address token, uint256 amount) 
            external 
            onlyWalletRouter 
            onlySupportedToken(token) 
            whenNotPaused 
            nonReentrant  
        {
            if (totalDeposits[token] < amount) revert  Error.InsufficientTrackedDeposits();
            
            if (token == address(0)) {
                if (address(this).balance < amount) revert  Error.InsufficientVaultETHBalance();
            } else {
                if (IERC20Upgradeable(token).balanceOf(address(this)) < amount) revert  Error.InsufficientVaultTokenBalance();
            }
            
            totalDeposits[token] -= amount;
            
            if (token == address(0)) {
                payable(recipient).sendValue(amount);
            } else {
                IERC20Upgradeable(token).safeTransfer(recipient, amount);
            }
            emit WithdrawalProcessed(recipient, token, amount);

    }

    /// @notice Adds a token to the supported tokens list.
    /// @param token Token address to add (address(0) for ETH).
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if token is already supported or if a non-ETH token is not a contract. Emits TokenSupportAdded event.
    function addSupportedToken(address token) external onlyVaultAdmin {
        if (supportedTokens[token]) revert  Error.TokenAlreadySupported();
        if (token != address(0)) {
            if (!isContract(token)) revert  Error.TokenIsNotAContract();
        }
        supportedTokens[token] = true;
        emit TokenSupportAdded(token);
    }

    /// @notice Removes a token from the supported tokens list.
    /// @param token Token address to remove (address(0) for ETH).
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if token is not supported, or if token/ETH has remaining deposits or balance. Emits TokenSupportRemoved event.
    function removeSupportedToken(address token) external onlyVaultAdmin {
        if (!supportedTokens[token]) revert  Error.TokenNotSupported();
        if (totalDeposits[token] != 0) revert  Error.CannotRemoveTokenWithDeposits();
        if (token == address(0)) {
            if (address(this).balance != 0) revert  Error.VaultHasETHBalance();
        } else {
            if (IERC20Upgradeable(token).balanceOf(address(this)) != 0) revert Error.VaultHasTokenBalance();
        }
        supportedTokens[token] = false;
        emit TokenSupportRemoved(token);
    }

    /// @notice Proposes sweeping untracked (dust) tokens or ETH via the Timelock.
    /// @param token Token address to sweep (address(0) for ETH).
    /// @param to Address to receive the swept funds.
    /// @param amount Amount of tokens or ETH to sweep.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if recipient is zero or amount is zero. Calls Timelock to propose the action.
    function proposeSweepDust(address token, address to, uint256 amount) external onlyVaultAdmin {
        if (to == address(0)) revert Error.InvalidRecipient();
        if (amount == 0) revert  Error.InvalidAmount();
        timelock.proposeSweepDust(token, to, amount, SWEEP_DUST);
    }

    /// @notice Executes sweeping of untracked (dust) tokens or ETH after timelock validation.
    /// @param token Token address to sweep (address(0) for ETH).
    /// @param to Recipient address to receive the swept funds.
    /// @param amount Amount of tokens or ETH to sweep.
    /// @param actionId Unique identifier of the proposed action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if amount is zero, token is supported, timelock execution fails, or insufficient untracked balance. Emits DustSwept event.
    function sweepDust(address token, address  to, uint256 amount, bytes32 actionId) external onlyVaultAdmin {
        if (amount == 0) revert Error.InvalidAmount();
        if (!timelock.executeSweepDust(actionId, token, to, amount)) revert Error.ExecutionFailed();

        if (token == address(0)) {
            uint256 unaccountedETH = address(this).balance - totalDeposits[address(0)];
            if (amount > unaccountedETH) revert  Error.CannotSweepTokenWithDeposit();
            payable(to).sendValue(amount);
        } else {
            if (!isContract(token)) revert  Error.TokenIsNotAContract();
            uint256 unaccounted = IERC20Upgradeable(token).balanceOf(address(this)) - totalDeposits[token];
            if (amount >  unaccounted) revert  Error.CannotSweepTokenWithDeposit();
            IERC20Upgradeable(token).safeTransfer(to, amount);
        }
        emit DustSwept(token, to, amount);
    }

    /// @notice Proposes setting a new WalletRouter address via the Timelock.
    /// @param _walletRouter Proposed new WalletRouter address.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if address is zero. Calls Timelock to propose the action.
    function proposeSetWalletRouter(address _walletRouter) external onlyVaultAdmin {
        if (_walletRouter == address(0)) revert  Error.InvalidWalletRouter();
        timelock.proposeSetWalletRouter(_walletRouter, SET_WALLETROUTER);
    }

    /// @notice Executes setting a new WalletRouter address after timelock validation.
    /// @param _walletRouter New WalletRouter address.
    /// @param actionId Unique identifier of the proposed action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if timelock execution fails. Updates walletRouter and emits WalletRouterSet event.
    function setWalletRouter(address _walletRouter, bytes32 actionId) external onlyVaultAdmin {
        if (!timelock.executeSetWalletRouter(actionId, _walletRouter)) revert  Error.SetWalletRouterNotExecuted();
        walletRouter = _walletRouter;
        emit WalletRouterSet(_walletRouter);
    }

    /// @notice Proposes recovering funds from the Vault via the Timelock.
    /// @param token Token address to recover (address(0) for ETH).
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens or ETH to recover.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if recipient is zero. Calls Timelock to propose the action.
    function proposeRecoverFunds(address token, address recipient, uint256 amount) external onlyVaultAdmin {
        if (recipient == address(0)) revert  Error.InvalidRecipient();
        if (amount == 0) revert Error.InvalidAmount();
        if (!supportedTokens[token]) revert  Error.TokenNotSupported();
        timelock.proposeRecoverFunds(token, recipient, amount, RECOVER_FUNDS);
    }

    /// @notice Executes recovering funds from the Vault after timelock validation.
    /// @param token Token address to recover (address(0) for ETH).
    /// @param recipient Address to receive the recovered funds.
    /// @param amount Amount of tokens or ETH to recover.
    /// @param actionId Unique identifier of the proposed action.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if timelock execution fails or insufficient tracked deposits. Updates totalDeposits and emits FundsRecovered event.
    function recoverFunds(address token, address recipient, uint256 amount, bytes32 actionId) external onlyVaultAdmin {
        if (!timelock.executeRecoverFunds(actionId, token, recipient, amount)) revert  Error.RecoverFundsNotExecuted();
        if (totalDeposits[token] < amount) revert  Error.InsufficientTrackedDeposits();
        totalDeposits[token] -= amount;
        if (token == address(0)) {
            payable(recipient).sendValue(amount);
        } else {
            IERC20Upgradeable(token).safeTransfer(recipient, amount);
        }
        emit FundsRecovered(token, recipient, amount);
    }

    /// @notice Pauses deposits and withdrawals in the Vault.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Triggers PausableUpgradeable’s _pause function.
    function pause() external onlyVaultAdmin {
        _pause();
    }

    /// @notice Unpauses deposits and withdrawals in the Vault.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Triggers PausableUpgradeable’s _unpause function.
    function unpause() external onlyVaultAdmin {
        _unpause();
    }

    /// @notice Authorizes a contract upgrade for the UUPS proxy.
    /// @param newImplementation Address of the new implementation contract.
    /// @dev Only callable by VAULT_ADMIN_ROLE. Reverts if address is zero or not a contract. Required for UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal onlyVaultAdmin override {
        if (newImplementation == address(0)) revert  Error.InvalidImplementationAddress();
        if (!isContract(newImplementation)) revert  Error.ImplementationIsNotAContract();
    }

    /// @notice Checks if an address is a contract.
    /// @param addr Address to check.
    /// @return True if the address has code (is a contract), false otherwise.
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    /// @notice Allows the Vault to receive ETH directly.
    /// @dev Accepts ETH transfers without reverting, typically for untracked (dust) ETH.
    receive() external payable {}
    uint256[50] private __gap;

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/vault/Vault.sol";
import "../contracts/router/WalletRouter.sol";
import "../contracts/access/RoleManager.sol";
import "../contracts/timelock/Timelock.sol";
import "../contracts/error/Error.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20Upgradeable {
    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultSystemTest is Test {
    Vault vault;
    WalletRouter walletRouter;
    RoleManager roleManager;
    Timelock timelock;
    MockERC20 token;

    address multiSigAdmin = address(0x123);
    address user1 = address(0x789);
    address user2 = address(0xABC);
    address operator = address(0xDEF);

    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant SET_WALLETROUTER = keccak256("SET_WALLETROUTER");
    bytes32 constant SET_VAULT = keccak256("SET_VAULT");
    bytes32 constant RECOVER_FUNDS = keccak256("RECOVER_FUNDS");

    function setUp() public {
        vm.startPrank(multiSigAdmin);

        // Deploy RoleManager
        roleManager = new RoleManager(multiSigAdmin);

        // Deploy Timelock
        timelock = new Timelock(address(roleManager));

        // Deploy WalletRouter
        walletRouter = new WalletRouter(address(roleManager), address(timelock));

        // Deploy Vault implementation
        address vaultImpl = address(new Vault());

        // Deploy Vault proxy
        bytes memory initData = abi.encodeWithSelector(
            Vault.initialize.selector,
            address(roleManager),
            address(walletRouter),
            address(timelock)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(vaultImpl, initData);
        vault = Vault (payable(address(proxy)));

        // // Update Timelock with correct addresses
        // bytes32 actionId = keccak256(abi.encode(SET_VAULT, address(vault), block.timestamp));
        // timelock.proposeSetVault(SET_VAULT, address(vault), multiSigAdmin);
        // vm.warp(block.timestamp + 1 days + 1);
        // timelock.executeSetVault(actionId, address(vault), multiSigAdmin);

        // actionId = keccak256(abi.encode(SET_WALLETROUTER, address(walletRouter), block.timestamp));
        // timelock.proposeSetWalletRouter(address(walletRouter), SET_WALLETROUTER , multiSigAdmin);
        // vm.warp(block.timestamp + 1 days + 1);
        // timelock.executeSetWalletRouter(actionId, address(walletRouter) , multiSigAdmin);

        // Set Vault in WalletRouter
        // actionId = keccak256(abi.encode(SET_VAULT, address(vault), block.timestamp));
        // walletRouter.proposeSetVault(address(vault));
        // vm.warp(block.timestamp + 1 days + 1);
        walletRouter.setVault(address(vault));
        timelock.setVault(address(vault));

        // Deploy and initialize Mock ERC20 token
        token = new MockERC20();
        token.initialize("Test Token", "TST");

        // Mint tokens and fund users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Grant roles
        bytes32 actionId = keccak256(abi.encode(OPERATOR_ROLE, operator, true, block.timestamp));
        roleManager.proposeGrantRole(OPERATOR_ROLE, operator);
        vm.warp(block.timestamp + 1 days + 1);
        roleManager.executeRoleAction(actionId);

        actionId = keccak256(abi.encode(VAULT_ADMIN_ROLE, multiSigAdmin, true, block.timestamp));
        roleManager.proposeGrantRole(VAULT_ADMIN_ROLE, multiSigAdmin);
        vm.warp(block.timestamp + 1 days + 1);
        roleManager.executeRoleAction(actionId);

        actionId = keccak256(abi.encode(ROUTER_ADMIN_ROLE, multiSigAdmin, true, block.timestamp));
        roleManager.proposeGrantRole(ROUTER_ADMIN_ROLE, multiSigAdmin);
        vm.warp(block.timestamp + 1 days + 1);
        roleManager.executeRoleAction(actionId);

        vm.stopPrank();
    }

    function testInitializeVault() public {
        assertEq(address(vault.roleManager()), address(roleManager));
        assertEq(address(vault.timelock()), address(timelock));
        assertEq(vault.walletRouter(), address(walletRouter));
        assertTrue(vault.isSupportedToken(address(0)));
        assertTrue(roleManager.hasRole(VAULT_ADMIN_ROLE, multiSigAdmin));
        assertTrue(roleManager.hasRole(ROUTER_ADMIN_ROLE, multiSigAdmin));
        assertEq(address(walletRouter.vault()), address(vault));
    }

    function testAddRemoveSupportedToken() public {

        vm.startPrank(multiSigAdmin);
        // bytes32 actionId = keccak256(abi.encode(ADD_TOKEN, address(token), block.timestamp));
        // vault.proposeAddToken(address(token));
        // vm.warp(block.timestamp + 1 days + 1);
        vault.addSupportedToken(address(token));
        assertTrue(vault.isSupportedToken(address(token)));

        // Deposit to prevent removal
        vm.stopPrank();
        vm.prank(user1);
        token.approve(address(walletRouter), 100 ether);
        vm.prank(user1);
        walletRouter.deposit(address(token), 100 ether);

        vm.prank(multiSigAdmin);
        vm.expectRevert(Error.CannotRemoveTokenWithDeposits.selector);
        vault.removeSupportedToken(address(token));

        // Withdraw and remove
        vm.prank(multiSigAdmin);
        walletRouter.withdraw(user1, address(token), 100 ether);        
        vm.prank(multiSigAdmin);
        vault.removeSupportedToken(address(token));
        assertFalse(vault.isSupportedToken(address(token)));
    }

    function testETHDepositAndWithdrawal() public {
        vm.prank(user1);
        walletRouter.deposit{value: 1 ether}(address(0), 1 ether);
        assertEq(vault.totalDeposits(address(0)), 1 ether);
        assertEq(address(vault).balance, 1 ether);

        vm.prank(operator);
        walletRouter.withdraw(user2, address(0), 0.5 ether);
        assertEq(vault.totalDeposits(address(0)), 0.5 ether);
        assertEq(address(vault).balance, 0.5 ether);
        assertEq(user2.balance, 100.5 ether);
    }

    function testERC20DepositAndWithdrawal() public {
        vm.startPrank(multiSigAdmin);
        // bytes32 actionId = keccak256(abi.encode(ADD_TOKEN, address(token), block.timestamp));
        // vault.proposeAddToken(address(token));
        // vm.warp(block.timestamp + 1 days + 1);
        vault.addSupportedToken(address(token));
        vm.stopPrank();

        vm.prank(user1);
        token.approve(address(walletRouter), 100 ether);
        vm.prank(user1);
        walletRouter.deposit(address(token), 100 ether);
        assertEq(vault.totalDeposits(address(token)), 100 ether);
        assertEq(token.balanceOf(address(vault)), 100 ether);

        vm.prank(operator);
        walletRouter.withdraw(user2, address(token), 50 ether);
        assertEq(vault.totalDeposits(address(token)), 50 ether);
        assertEq(token.balanceOf(address(vault)), 50 ether);
        assertEq(token.balanceOf(user2), 1050 ether);
    }

    function testRecoverFunds() public {
        vm.prank(user1);
        walletRouter.deposit{value: 1 ether}(address(0), 1 ether);

        vm.startPrank(multiSigAdmin);
        bytes32 actionId = keccak256(abi.encode(RECOVER_FUNDS, address(0), user2, 0.5 ether, block.timestamp));
        vault.proposeRecoverFunds(address(0), user2, 0.5 ether );
        vm.warp(block.timestamp + 1 days + 1);
        vault.recoverFunds(address(0), user2, 0.5 ether, actionId);

        assertEq(vault.totalDeposits(address(0)), 0.5 ether);
        assertEq(address(vault).balance, 0.5 ether);
        assertEq(user2.balance, 100.5 ether);
    }

    function testVaultAccessControl() public {
        vm.prank(user1);
        vm.expectRevert(Error.CallerLacksVaultAdminRole.selector);
        vault.addSupportedToken(address(token));

        vm.prank(user1);
        vm.expectRevert(Error.InvalidWalletRouter.selector);
        vault.handleDeposit{value: 1 ether}(user1, address(0), 1 ether);
    }

    function testWalletRouterAccessControl() public {
        vm.prank(user1);
        vm.expectRevert(Error.NotOperator.selector);
        walletRouter.withdraw(user2, address(0), 1 ether);

        vm.prank(user1);
        vm.expectRevert(Error.NotRouterAdmin.selector);
        walletRouter.pause();
    }

    function testTimelockOperations() public {
        vm.startPrank(multiSigAdmin);
        bytes32 actionId = keccak256(abi.encode(SET_WALLETROUTER, address(0x999), block.timestamp));
        vault.proposeSetWalletRouter(address(0x999));
        vm.expectRevert(Error.TimelockNotExpired.selector);
        vault.setWalletRouter(address(0x999), actionId);

        vm.warp(block.timestamp + 1 days + 1);
        vault.setWalletRouter(address(0x999), actionId);
        assertEq(vault.walletRouter(), address(0x999));
    }

    function testPauseFunctionality() public {
        vm.prank(multiSigAdmin);
        vault.pause();
        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        walletRouter.deposit{value: 1 ether}(address(0), 1 ether);

        vm.prank(multiSigAdmin);
        vault.unpause();
        vm.prank(user1);
        walletRouter.deposit{value: 1 ether}(address(0), 1 ether);
        assertEq(vault.totalDeposits(address(0)), 1 ether);
    }

    function testInvalidInputs() public {
        vm.prank(user1);
        vm.expectRevert(Error.InvalidAmount.selector);
        walletRouter.deposit{value: 0}(address(0), 0);

        vm.prank(user1);
        vm.expectRevert(Error.TokenNotSupported.selector);
        walletRouter.deposit(address(token), 100 ether);

        vm.prank(multiSigAdmin);
        vm.expectRevert(Error.InvalidWalletRouter.selector);
        vault.proposeSetWalletRouter(address(0));
    }

    function testUpgradeAuthorization() public {
        Vault newVaultImpl = new Vault();
        vm.prank(user1);
        vm.expectRevert(Error.CallerLacksVaultAdminRole.selector);
        vault.upgradeTo(address(newVaultImpl));

        vm.prank(multiSigAdmin);
        vault.upgradeTo(address(newVaultImpl));
    }

    function testAdminTransfer() public {
        vm.startPrank(multiSigAdmin);
        roleManager.proposeAdminTransfer(user1);
        vm.warp(block.timestamp + 1 days + 1);
        vm.stopPrank();

        vm.prank(user1);
        roleManager.acceptAdminTransfer();
        assertTrue(roleManager.hasRole(DEFAULT_ADMIN_ROLE, user1));
        assertFalse(roleManager.hasRole(DEFAULT_ADMIN_ROLE, multiSigAdmin));
    }

   // Add this to your VaultSystemTest contract

function testSweepDustETH() public {
    // Setup: Send ETH directly to vault (unsupported)
    vm.deal(address(vault), 5 ether);
    assertEq(address(vault).balance, 5 ether);
    assertEq(vault.totalDeposits(address(0)), 0); // No tracked deposits

    // Propose sweep
    vm.startPrank(multiSigAdmin);
    bytes32 actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(0),
        multiSigAdmin,
        3 ether,
        block.timestamp
    ));
    vault.proposeSweepDust(address(0), multiSigAdmin, 3 ether);
    
    // Attempt early execution (should fail)
    vm.expectRevert(Error.TimelockNotExpired.selector);
    vault.sweepDust(address(0), payable(multiSigAdmin), 3 ether, actionId);

    // Fast-forward and execute
    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);
    vault.sweepDust(address(0), payable(multiSigAdmin), 3 ether, actionId);

    // Verify
    assertEq(address(vault).balance, 2 ether); // 5 - 3
    assertEq(multiSigAdmin.balance, 3 ether);
}

function testSweepDustERC20() public {
    // Deploy and mint dust token (unsupported)
    MockERC20 dustToken = new MockERC20();
    dustToken.initialize("Dust", "DST");
    dustToken.mint(address(vault), 1000 ether);

    // Propose sweep
    vm.startPrank(multiSigAdmin);
    bytes32 actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(dustToken),
        multiSigAdmin,
        500 ether,
        block.timestamp
    ));
    vault.proposeSweepDust(address(dustToken), multiSigAdmin, 500 ether);
    
    // Execute after delay
    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);
    vault.sweepDust(address(dustToken), payable(multiSigAdmin), 500 ether, actionId);

    // Verify
    assertEq(dustToken.balanceOf(address(vault)), 500 ether);
    assertEq(dustToken.balanceOf(multiSigAdmin), 500 ether);
}

// function testCannotSweepSupportedTokens() public {
//     // Setup supported token deposit
//     vm.startPrank(multiSigAdmin);
//     vault.addSupportedToken(address(token));
//     vm.stopPrank();

//     vm.prank(user1);
//     token.approve(address(walletRouter), 100 ether);
//     vm.prank(user1);
//     walletRouter.deposit(address(token), 100 ether);

//     // Attempt to sweep (should fail)
//     vm.startPrank(multiSigAdmin);
//     vm.expectRevert("Cannot sweep supported tokens");
//     vault.proposeSweepDust(address(token), multiSigAdmin, 50 ether);
// }

function testCannotSweepDepositedETH() public {
    // Make a deposit
    vm.prank(user1);
    walletRouter.deposit{value: 2 ether}(address(0), 2 ether);

    // Send extra ETH directly (dust)
    vm.deal(address(vault), 5 ether); // 2 deposited + 3 dust

    // Should only allow sweeping the dust (3 ETH)
    vm.startPrank(multiSigAdmin);
    bytes32 actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(0),
        multiSigAdmin,
        4 ether, // Attempt to over-sweep
        block.timestamp
    ));
    vault.proposeSweepDust(address(0), multiSigAdmin, 4 ether);
    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);
    
    vm.expectRevert(Error.CannotSweepTokenWithDeposit.selector);
    vault.sweepDust(address(0), payable(multiSigAdmin), 4 ether, actionId);

    // Should succeed with correct amount (3 ETH)
    actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(0),
        multiSigAdmin,
        3 ether,
        block.timestamp
    ));
    vault.proposeSweepDust(address(0), multiSigAdmin, 3 ether);
    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);
    vault.sweepDust(address(0), payable(multiSigAdmin), 3 ether, actionId);
}

function testSweepDustAccessControl() public {
    // Non-admin cannot propose
    vm.prank(user1);
    vm.expectRevert(Error.CallerLacksVaultAdminRole.selector);
    vault.proposeSweepDust(address(0), user1, 1 ether);

    // Non-admin cannot execute
    vm.startPrank(multiSigAdmin);
    bytes32 actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(0),
        multiSigAdmin,
        1 ether,
        block.timestamp
    ));
    vault.proposeSweepDust(address(0), multiSigAdmin, 1 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);
    vm.prank(user1);
    vm.expectRevert(Error.CallerLacksVaultAdminRole.selector);
    vault.sweepDust(address(0), payable(multiSigAdmin), 1 ether, actionId);
}

function testSweepDustParameterTampering() public {
    // Setup dust
    vm.deal(address(vault), 5 ether);

    // Propose with correct params
    vm.startPrank(multiSigAdmin);
    bytes32 actionId = keccak256(abi.encode(
        vault.SWEEP_DUST(),
        address(0),
        multiSigAdmin,
        3 ether,
        block.timestamp
    ));
    vault.proposeSweepDust(address(0), multiSigAdmin, 3 ether);
    vm.warp(block.timestamp + timelock.MIN_TIMELOCK_DELAY() + 1);

    // Attempt to tamper with recipient
    vm.expectRevert(Error.RecipientMismatch.selector);
    vault.sweepDust(address(0), payable(user1), 3 ether, actionId); // Wrong recipient

    // Attempt to tamper with amount
    vm.expectRevert(Error.AmountMismatch.selector);
    vault.sweepDust(address(0), payable(multiSigAdmin), 4 ether, actionId); // Wrong amount
}


}
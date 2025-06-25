// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/vault/Vault.sol";
import "../contracts/router/WalletRouter.sol";
import "../contracts/access/RoleManager.sol";
import "../contracts/timelock/Timelock.sol";
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
    bytes32 constant ADD_TOKEN = keccak256("ADD_TOKEN");
    bytes32 constant REMOVE_TOKEN = keccak256("REMOVE_TOKEN");
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
        vault = Vault(address(proxy));

        // Update Timelock with correct addresses
        bytes32 actionId = keccak256(abi.encode(SET_VAULT, address(vault), block.timestamp));
        timelock.proposeSetVault(SET_VAULT, address(vault), multiSigAdmin);
        vm.warp(block.timestamp + 1 days + 1);
        timelock.executeSetVault(actionId, address(vault), multiSigAdmin);

        actionId = keccak256(abi.encode(SET_WALLETROUTER, address(walletRouter), block.timestamp));
        timelock.proposeSetWalletRouter(address(walletRouter), SET_WALLETROUTER , multiSigAdmin);
        vm.warp(block.timestamp + 1 days + 1);
        timelock.executeSetWalletRouter(actionId, address(walletRouter) , multiSigAdmin);

        // Set Vault in WalletRouter
        actionId = keccak256(abi.encode(SET_VAULT, address(vault), block.timestamp));
        walletRouter.proposeSetVault(address(vault));
        vm.warp(block.timestamp + 1 days + 1);
        walletRouter.setVault(address(vault), actionId);

        // Deploy and initialize Mock ERC20 token
        token = new MockERC20();
        token.initialize("Test Token", "TST");

        // Mint tokens and fund users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Grant roles
        actionId = keccak256(abi.encode(OPERATOR_ROLE, operator, true, block.timestamp));
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
        bytes32 actionId = keccak256(abi.encode(ADD_TOKEN, address(token), block.timestamp));
        vault.proposeAddToken(address(token));
        vm.warp(block.timestamp + 1 days + 1);
        vault.addSupportedToken(address(token), actionId);
        assertTrue(vault.isSupportedToken(address(token)));

        // Deposit to prevent removal
        vm.stopPrank();
        vm.prank(user1);
        token.approve(address(walletRouter), 100 ether);
        vm.prank(user1);
        walletRouter.deposit(address(token), 100 ether);

        vm.prank(multiSigAdmin);
        vm.expectRevert("Cannot remove token with deposits");
        vault.proposeRemoveToken(address(token));

        // Withdraw and remove
        vm.prank(multiSigAdmin);
        walletRouter.withdraw(user1, address(token), 100 ether);
        vm.prank(multiSigAdmin);
        actionId = keccak256(abi.encode(REMOVE_TOKEN, address(token), block.timestamp));
        vault.proposeRemoveToken(address(token));
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(multiSigAdmin);
        vault.removeSupportedToken(address(token), actionId);
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
        bytes32 actionId = keccak256(abi.encode(ADD_TOKEN, address(token), block.timestamp));
        vault.proposeAddToken(address(token));
        vm.warp(block.timestamp + 1 days + 1);
        vault.addSupportedToken(address(token), actionId);
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
        vm.expectRevert("Caller lacks VAULT_ADMIN_ROLE");
        vault.proposeAddToken(address(token));

        vm.prank(user1);
        vm.expectRevert("Not WalletRouter");
        vault.handleDeposit{value: 1 ether}(user1, address(0), 1 ether);
    }

    function testWalletRouterAccessControl() public {
        vm.prank(user1);
        vm.expectRevert("Not operator");
        walletRouter.withdraw(user2, address(0), 1 ether);

        vm.prank(user1);
        vm.expectRevert("Not router admin");
        walletRouter.pause();
    }

    function testTimelockOperations() public {
        vm.startPrank(multiSigAdmin);
        bytes32 actionId = keccak256(abi.encode(SET_WALLETROUTER, address(0x999), block.timestamp));
        vault.proposeSetWalletRouter(address(0x999));
        vm.expectRevert("Timelock not expired");
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
        vm.expectRevert("Invalid amount");
        walletRouter.deposit{value: 0}(address(0), 0);

        vm.prank(user1);
        vm.expectRevert("Token not supported");
        walletRouter.deposit(address(token), 100 ether);

        vm.prank(multiSigAdmin);
        vm.expectRevert("Invalid WalletRouter");
        vault.proposeSetWalletRouter(address(0));
    }

    function testUpgradeAuthorization() public {
        Vault newVaultImpl = new Vault();
        vm.prank(user1);
        vm.expectRevert("Caller lacks VAULT_ADMIN_ROLE");
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

    // function testEventEmissions() public {
    //     vm.startPrank(multiSigAdmin);
    //     bytes32 actionId = keccak256(abi.encode(ADD_TOKEN, address(token), block.timestamp));
    //     vm.expectEmit(true, true, false, true);
    //     emit vault.TokenSupportAdded(address(token));
    //     vault.proposeAddToken(address(token));
    //     vm.warp(block.timestamp + 1 days + 1);
    //     vault.addSupportedToken(address(token), actionId);

    //     vm.stopPrank();
    //     vm.prank(user1);
    //     token.approve(address(walletRouter), 100 ether);
    //     vm.expectEmit(true, true, false, true);
    //     emit walletRouter.Deposit(user1, address(token), 100 ether, block.timestamp);
    //     walletRouter.deposit(address(token), 100 ether);
    // }
}
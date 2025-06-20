// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/access/RoleManager.sol";
import "../contracts/vault/Vault.sol";
import "../contracts/router/WalletRouter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals);
    }
}

contract VaultTest is Test {
    address admin = address(1);
    address operator = address(2);
    address user = address(3);
    address nonOperator = address(4);
    address eth = address(0); // Native coin (ETH)

    MockERC20 usdc;
    RoleManager roleManager;
    Vault vault;
    WalletRouter router;

    uint256 constant ETH_AMOUNT = 0.1 ether; // 0.1 ETH
    uint256 constant USDC_AMOUNT = 100 * 10**6; // 100 USDC (6 decimals)

    function setUp() public {
        vm.startPrank(admin);

        // Deploy MockERC20 for USDC (6 decimals)
        usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed at:", address(usdc));

        // Deploy RoleManager
        roleManager = new RoleManager(admin);
        console.log("RoleManager deployed at:", address(roleManager));

        // Deploy WalletRouter
        router = new WalletRouter(address(roleManager));
        console.log("Router deployed at:", address(router));

        // Deploy Vault (upgradeable)
        address vaultImpl = address(new Vault());
        console.log("Vault implementation deployed at:", vaultImpl);

        bytes memory initializationData = abi.encodeWithSelector(
            Vault.initialize.selector,
            address(roleManager),
            admin,
            address(router)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(vaultImpl, "");
        console.log("Proxy deployed at:", address(proxy));

        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(proxy));
        (bool success, ) = address(proxy).call(initializationData);
        require(success, "Proxy init failed");

        vault = Vault(address(proxy));
        console.log("Vault proxy set at:", address(vault));

        // Set Vault in WalletRouter
        roleManager.grantRole(roleManager.ROUTER_ADMIN_ROLE(), admin);
        router.setVault(address(vault));

        // Grant OPERATOR_ROLE to operator
        console.log("Granting OPERATOR_ROLE to operator:", operator);
        roleManager.grantRole(roleManager.OPERATOR_ROLE(), operator);

        // Add USDC as supported token
        console.log("Adding USDC as supported token:", address(usdc));
        vault.addSupportedToken(address(usdc));

        // Verify roles and token support
        assertTrue(roleManager.hasRole(roleManager.OPERATOR_ROLE(), operator), "Operator role not granted");
        assertTrue(roleManager.hasRole(roleManager.VAULT_ADMIN_ROLE(), admin), "Vault admin role not granted");
        assertTrue(roleManager.hasRole(roleManager.ROUTER_ADMIN_ROLE(), admin), "Router admin role not granted");
        assertTrue(vault.supportedTokens(address(0)), "ETH not supported");
        assertTrue(vault.supportedTokens(address(usdc)), "USDC not supported");

        // Fund user with ETH and USDC
        vm.deal(user, 10 ether);
        usdc.transfer(user, 1000 * 10**6); // 1000 USDC
        console.log("User ETH balance:", user.balance);
        console.log("User USDC balance:", usdc.balanceOf(user));

        vm.stopPrank();
    }

    function testDepositETHSuccess() public {
        uint256 initialUserBalance = user.balance;
        uint256 initialVaultBalance = address(vault).balance;
        uint256 initialTotalDeposits = vault.totalDeposits(eth);

        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(vault));
        emit DepositProcessed(user, eth, ETH_AMOUNT);
        vm.expectEmit(true, true, false, true, address(router));
        emit Deposit(user, eth, ETH_AMOUNT);
        router.deposit{value: ETH_AMOUNT}(eth, ETH_AMOUNT);

        assertEq(user.balance, initialUserBalance - ETH_AMOUNT, "User ETH balance incorrect");
        assertEq(address(vault).balance, initialVaultBalance + ETH_AMOUNT, "Vault ETH balance incorrect");
        assertEq(vault.totalDeposits(eth), initialTotalDeposits + ETH_AMOUNT, "Total ETH deposits incorrect");
    }

    function testDepositUSDCSuccess() public {
        uint256 initialUserBalance = usdc.balanceOf(user);
        uint256 initialVaultBalance = usdc.balanceOf(address(vault));
        uint256 initialTotalDeposits = vault.totalDeposits(address(usdc));

        vm.startPrank(user);
        usdc.approve(address(router), USDC_AMOUNT);
        console.log("User approves router for USDC amount:", USDC_AMOUNT);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit Transfer(user, address(vault), USDC_AMOUNT);
        vm.expectEmit(true, true, false, true, address(vault));
        emit DepositProcessed(user, address(usdc), USDC_AMOUNT);
        vm.expectEmit(true, true, false, true, address(router));
        emit Deposit(user, address(usdc), USDC_AMOUNT);
        router.deposit(address(usdc), USDC_AMOUNT);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user), initialUserBalance - USDC_AMOUNT, "User USDC balance incorrect");
        assertEq(usdc.balanceOf(address(vault)), initialVaultBalance + USDC_AMOUNT, "Vault USDC balance incorrect");
        assertEq(vault.totalDeposits(address(usdc)), initialTotalDeposits + USDC_AMOUNT, "Total USDC deposits incorrect");
    }

    function testDepositZeroAmountFails() public {
        vm.prank(user);
        vm.expectRevert("Invalid amount");
        router.deposit{value: 0}(eth, 0);

        vm.startPrank(user);
        usdc.approve(address(router), 0);
        vm.expectRevert("Invalid amount");
        router.deposit(address(usdc), 0);
        vm.stopPrank();
    }

    function testDepositIncorrectETHAmountFails() public {
        vm.prank(user);
        vm.expectRevert("Incorrect ETH amount");
        router.deposit{value: ETH_AMOUNT + 1}(eth, ETH_AMOUNT);
    }

    function testDepositETHForERC20Fails() public {
        vm.startPrank(user);
        usdc.approve(address(router), USDC_AMOUNT);
        vm.expectRevert("ETH not allowed for ERC20 deposit");
        router.deposit{value: ETH_AMOUNT}(address(usdc), USDC_AMOUNT);
        vm.stopPrank();
    }

    function testDepositUnsupportedTokenFails() public {
        address unsupportedToken = address(0xDEAD);
        vm.startPrank(user);
        vm.expectRevert("Token not supported");
        router.deposit(unsupportedToken, USDC_AMOUNT);
        vm.stopPrank();
    }

    function testDepositDirectToVaultFails() public {
        vm.prank(user);
        vm.expectRevert("Not WalletRouter");
        vault.handleDeposit{value: ETH_AMOUNT}(user, eth, ETH_AMOUNT);
    }

    function testWithdrawalETHSuccess() public {
        // Deposit ETH first
        vm.prank(user);
        router.deposit{value: ETH_AMOUNT}(eth, ETH_AMOUNT);

        uint256 initialUserBalance = user.balance;
        uint256 initialVaultBalance = address(vault).balance;
        uint256 initialTotalDeposits = vault.totalDeposits(eth);

        vm.prank(operator);
        vm.expectEmit(true, true, false, true, address(vault));
        emit WithdrawalProcessed(user, eth, ETH_AMOUNT);
        vm.expectEmit(true, true, false, true, address(router));
        emit Withdrawal(user, eth, ETH_AMOUNT);
        router.withdraw(user, eth, ETH_AMOUNT);

        assertEq(user.balance, initialUserBalance + ETH_AMOUNT, "User ETH balance incorrect");
        assertEq(address(vault).balance, initialVaultBalance - ETH_AMOUNT, "Vault ETH balance incorrect");
        assertEq(vault.totalDeposits(address(vault)), initialTotalDeposits - ETH_AMOUNT, "Total ETH deposits incorrect");
    }

    function testWithdrawalUSDCSuccess() public {
        // Deposit USDC
        vm.startPrank(user);
        usdc.approve(address(router), USDC_AMOUNT);
        // console.log("Deposit: user approves router for:", USDC_AMOUNT);
        // console.log("Vault USDC balance before deposit:", usdc.balanceOf(address(vault)));
        router.deposit(address(usdc), USDC_AMOUNT);
        // console.log("Vault USDC balance after deposit:", usdc.balanceOf(address(vault)));
        assertEq(usdc.balanceOf(address(vault)), USDC_AMOUNT, "Vault USDC balance not updated after deposit");
        vm.stopPrank();

        uint256 initialUserBalance = usdc.balanceOf(user);
        uint256 initialVaultBalance = usdc.balanceOf(address(vault));
        uint256 initialTotalDeposits = vault.totalDeposits(address(usdc));

        // console.log("Operator has OPERATOR_ROLE:", roleManager.hasRole(roleManager.OPERATOR_ROLE(), operator));
        // console.log("Vault USDC balance before withdrawal:", usdc.balanceOf(address(vault)));
        // console.log("Withdrawing:", USDC_AMOUNT, "of token:", address(usdc), "to:", user);

        vm.prank(operator);
        // Expect USDC Transfer event
        vm.expectEmit(true, true, false, true, address(usdc));
        emit Transfer(address(vault), user, USDC_AMOUNT);
        // Expect Vault WithdrawalProcessed event
        vm.expectEmit(true, true, false, true, address(vault));
        emit WithdrawalProcessed(user, address(usdc), USDC_AMOUNT);
        // Expect WalletRouter Withdrawal event
        vm.expectEmit(true, true, false, true, address(router));
        emit Withdrawal(user, address(usdc), USDC_AMOUNT);
        router.withdraw(user, address(usdc), USDC_AMOUNT);

        assertEq(usdc.balanceOf(user), initialUserBalance + USDC_AMOUNT, "User USDC balance incorrect");
        assertEq(usdc.balanceOf(address(vault)), initialVaultBalance - USDC_AMOUNT, "Vault USDC balance incorrect");
        assertEq(vault.totalDeposits(address(usdc)), initialTotalDeposits - USDC_AMOUNT, "Total USDC deposits incorrect");
    }

    function testWithdrawalNonOperatorFails() public {
        vm.prank(user);
        router.deposit{value: ETH_AMOUNT}(eth, ETH_AMOUNT);

        vm.prank(nonOperator);
        vm.expectRevert("Not operator");
        router.withdraw(user, eth, ETH_AMOUNT);
    }

    function testWithdrawalZeroAmountFails() public {
        vm.prank(user);
        router.deposit{value: ETH_AMOUNT}(eth, ETH_AMOUNT);

        vm.prank(operator);
        vm.expectRevert("Invalid amount");
        router.withdraw(user, eth, 0);
    }

    function testWithdrawalUnsupportedTokenFails() public {
        address unsupportedToken = address(0xDEAD);
        vm.prank(operator);
        vm.expectRevert("Token not supported");
        router.withdraw(user, unsupportedToken, USDC_AMOUNT);
    }

    function testWithdrawalDirectToVaultFails() public {
        vm.prank(user);
        router.deposit{value: ETH_AMOUNT}(eth, ETH_AMOUNT);

        vm.prank(operator);
        vm.expectRevert("Not WalletRouter");
        vault.handleWithdrawal(user, eth, ETH_AMOUNT);
    }

    function testAddSupportedTokenSuccess() public {
        address newToken = address(new MockERC20("Test Token", "TEST", 18));
        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(vault));
        emit TokenSupportAdded(newToken);
        vault.addSupportedToken(newToken);
        assertTrue(vault.supportedTokens(newToken), "Token not supported");
    }

    function testAddSupportedTokenNonAdminFails() public {
        address newToken = address(new MockERC20("Test Token", "TEST", 18));
        vm.prank(user);
        vm.expectRevert("Not admin");
        vault.addSupportedToken(newToken);
    }

    function testRemoveSupportedTokenSuccess() public {
        assertEq(vault.totalDeposits(address(usdc)), 0, "USDC has deposits");
        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(vault));
        emit TokenSupportRemoved(address(usdc));
        vault.removeSupportedToken(address(usdc));
        assertFalse(vault.supportedTokens(address(usdc)), "USDC still supported");
    }

    function testRemoveSupportedTokenWithDepositsFails() public {
        vm.startPrank(user);
        usdc.approve(address(router), USDC_AMOUNT);
        router.deposit(address(usdc), USDC_AMOUNT);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert("Cannot remove token with deposits");
        vault.removeSupportedToken(address(usdc));
    }

    // Events from WalletRouter and Vault
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed recipient, address indexed token, uint256 amount);
    event DepositProcessed(address indexed user, address indexed token, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, address indexed token, uint256 amount);
    event TokenSupportAdded(address indexed token);
    event TokenSupportRemoved(address indexed token);
    // Event from MockERC20
    event Transfer(address indexed from, address indexed to, uint256 value);
}

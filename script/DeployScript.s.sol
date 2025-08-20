// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";  
import "../contracts/access/RoleManager.sol";
import "../contracts/timelock/Timelock.sol";
import "../contracts/vault/Vault.sol";
import "../contracts/router/WalletRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

       
        // Specify multi-sig admin (for testing, same as deployer; in production, use a multi-sig contract)
        address multiSigAdmin = deployer; // Update to a multi-sig address in production
        console.log("Deployer:", deployer);
        console.log("Using multiSigAdmin:", multiSigAdmin);

        // Deploy RoleManager
        // @contract-name: RoleManager
        RoleManager roleManager = new RoleManager(multiSigAdmin);
        console.log("RoleManager deployed at:", address(roleManager));

        // Deploy TestToken with 1 million tokens (18 decimals)
        // uint256 initialSupply = 1_000_000 * 10**18;
        // @contract-name: TestToken
        // TestToken token = new TestToken(initialSupply);
        // console.log("TestToken deployed at:", address(token));

        // If deployer is not multiSigAdmin, grant ROUTER_ADMIN_ROLE to deployer for testing
        if (deployer != multiSigAdmin) {
            bytes32 routerAdminRole = roleManager.ROUTER_ADMIN_ROLE();
            bytes32 actionId = keccak256(abi.encode(routerAdminRole, deployer, true, block.timestamp));
            roleManager.proposeGrantRole(routerAdminRole, deployer);
            vm.warp(block.timestamp + 1 days + 1);
            roleManager.executeRoleAction(actionId);
            console.log("Granted ROUTER_ADMIN_ROLE to deployer for testing");
        }

        // Deploy Timelock with RoleManager address
        // @contract-name: Timelock
        Timelock timelock = new Timelock(address(roleManager));
        console.log("Timelock deployed at:", address(timelock));

        // Deploy WalletRouter with RoleManager and Timelock addresses
        // @contract-name: WalletRouter
        WalletRouter walletRouter = new WalletRouter(address(roleManager), address(timelock));
        console.log("WalletRouter deployed at:", address(walletRouter));

        // @contract-name: Vault
        // Deploy Vault implementation (UUPS pattern)
        Vault vaultImplementation = new Vault();
        console.log("Vault implementation deployed at:", address(vaultImplementation));

        // Deploy Vault proxy and initialize it with WalletRouter address
        bytes memory initData = abi.encodeWithSelector(
            Vault.initialize.selector,
            address(roleManager),
            address(walletRouter),
            address(timelock)
        );
        
        ERC1967Proxy  vaultProxy = new ERC1967Proxy(address(vaultImplementation), initData);
        console.log("Vault proxy deployed at:", address(vaultProxy));
        Vault vault = Vault(payable(vaultProxy));

        walletRouter.setVault(address(vault));
        console.log("Vault set in WalletRouter");
        timelock.setVault(address(vault));
        console.log("Vault set in Timelock");

        // Verify initial setup
        console.log("Verifying setup...");
        require(roleManager.hasRole(roleManager.DEFAULT_ADMIN_ROLE(), multiSigAdmin), "Admin role not set");
        require(vault.isSupportedToken(address(0)), "ETH support not enabled");
        require(vault.walletRouter() == address(walletRouter), "WalletRouter not set in Vault");
        console.log("Setup verified successfully");

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
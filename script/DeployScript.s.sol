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
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        address operator0 = vm.addr(operatorPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Operator (Admin):", operator0);

        /* ---------------- DEPLOYMENT (DEPLOYER) ---------------- */

        vm.startBroadcast(deployerPrivateKey);

        RoleManager roleManager = new RoleManager(operator0);
        console.log("RoleManager:", address(roleManager));

        Timelock timelock = new Timelock(address(roleManager));
        console.log("Timelock:", address(timelock));

        WalletRouter walletRouter =
            new WalletRouter(address(roleManager), address(timelock));
        console.log("WalletRouter:", address(walletRouter));

        Vault vaultImplementation = new Vault();
        console.log("Vault implementation:", address(vaultImplementation));

        bytes memory initData = abi.encodeWithSelector(
            Vault.initialize.selector,
            address(roleManager),
            address(walletRouter),
            address(timelock)
        );

        ERC1967Proxy vaultProxy =
            new ERC1967Proxy(address(vaultImplementation), initData);

        Vault vault = Vault(payable(address(vaultProxy)));
        console.log("Vault proxy:", address(vault));

        vm.stopBroadcast();

        /* ---------------- ADMIN SETUP (OPERATOR0) ---------------- */

        vm.startBroadcast(operatorPrivateKey);

        walletRouter.setVault(address(vault));
        console.log("Vault set in WalletRouter");

        timelock.setVault(address(vault));
        console.log("Vault set in Timelock");

        vm.stopBroadcast();

        console.log("Deployment & admin setup complete");
    }
}

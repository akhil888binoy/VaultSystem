// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Script.sol";
// import "../contracts/vault/VaultV2.sol";
// import "../contracts/vault/Vault.sol";

// contract UpgradeVaultScript is Script {
//     function setUp() public {}

//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         // 🔐 Call upgradeTo on proxy using Vault interface
//         Vault proxy = Vault(payable(vm.envAddress("VAULT_PROXY")));
//         VaultV2 newImpl = new VaultV2();
//         proxy.upgradeTo(address(newImpl));
//         console.log("Vault Address =", address(newImpl));
//         console.log("Vault upgraded to VaultV2 implementation");

//         vm.stopBroadcast();
//     }
// }

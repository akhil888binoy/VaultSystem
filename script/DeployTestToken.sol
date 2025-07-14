// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/TestToken/TestToken.sol";

contract DeployTestToken is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TestToken with 1 million tokens (18 decimals)
        uint256 initialSupply = 1_000_000 * 10**18;
        TestToken token = new TestToken(initialSupply);
        console.log("TestToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}

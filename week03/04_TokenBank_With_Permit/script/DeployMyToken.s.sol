// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MyToken contract with name "My Token" and symbol "MTK"
        MyToken token = new MyToken("My Token", "MTK");

        vm.stopBroadcast();
        
        // Log the token address
        console.log("Token deployed at:", address(token));
    }
} 
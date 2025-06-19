// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployTokenBank is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MyToken contract or use an existing one
        MyToken token = new MyToken("My Token", "MTK");
        console.log("Token deployed at:", address(token));

        // Deploy the TokenBank contract with the token address
        TokenBank bank = new TokenBank(address(token));
        console.log("TokenBank deployed at:", address(bank));

        vm.stopBroadcast();
    }
} 
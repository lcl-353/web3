// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {TestToken} from "../src/ERC20_WithPermit.sol";
import {TokenBank} from "../src/TokenBank_SupportPermit.sol";

contract DeployTokenBank is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MyToken contract or use an existing one
        TestToken token = new TestToken();
        console.log("Token deployed at:", address(token));

        // Deploy the TokenBank contract with the token address and default Permit2
        TokenBank bank = new TokenBank(address(token), address(0)); // 使用零地址让合约使用默认 Permit2 地址
        console.log("TokenBank deployed at:", address(bank));

        vm.stopBroadcast();
    }
} 
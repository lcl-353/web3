// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/ERC20.sol";

contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();

        // 构造函数传入参数
        MyToken token = new MyToken("MyToken", "MTK");

        vm.stopBroadcast();
    }
}


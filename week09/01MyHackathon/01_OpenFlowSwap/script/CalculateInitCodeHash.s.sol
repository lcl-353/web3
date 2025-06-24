// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/dex/SushiPair.sol";

contract CalculateInitCodeHash is Script {
    function run() external {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(SushiPair).creationCode));
        
        console.log("=== INIT CODE HASH CALCULATION ===");
        console.log("SushiPair init code hash:");
        console.logBytes32(initCodeHash);
        console.log("");
        console.log("Hex string format:");
        console.log("hex'%s'", vm.toString(initCodeHash));
    }
} 
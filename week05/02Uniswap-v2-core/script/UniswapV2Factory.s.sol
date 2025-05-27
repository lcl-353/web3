// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.5.16;

import "../src/UniswapV2Factory.sol";

// Basic interface needed for deploying
interface Vm {
    function envUint(string calldata) external returns (uint256);
    function addr(uint256) external returns (address);
    function startBroadcast(uint256) external;
    function stopBroadcast() external;
    function toString(address) external returns (string memory);
}

interface Console {
    function log(string calldata, address) external;
}

contract UniswapV2FactoryScript {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Console constant console = Console(0x000000000000000000636F6e736F6c652e6c6f67);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy UniswapV2Factory with the deployer as feeToSetter
        address deployer = vm.addr(deployerPrivateKey);
        UniswapV2Factory factory = new UniswapV2Factory(deployer);

        console.log("UniswapV2Factory deployed at:", address(factory));
        console.log("feeToSetter set to:", factory.feeToSetter());

        vm.stopBroadcast();
    }
}

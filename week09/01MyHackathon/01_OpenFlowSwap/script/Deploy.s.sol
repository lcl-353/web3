// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/mocks/ERC20Mock.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploy SushiToken
        SushiToken sushi = new SushiToken();
        console.log("SushiToken deployed at:", address(sushi));

        // Deploy SushiFactory
        SushiFactory factory = new SushiFactory(deployer);
        console.log("SushiFactory deployed at:", address(factory));

        // Deploy WETH mock (for testing)
        ERC20Mock weth = new ERC20Mock("Wrapped Ether", "WETH", 1000000 * 10**18);
        console.log("WETH mock deployed at:", address(weth));

        // Deploy SushiRouter
        SushiRouter router = new SushiRouter(address(factory), address(weth));
        console.log("SushiRouter deployed at:", address(router));

        // Deploy MasterChef
        uint256 sushiPerBlock = 1 * 10**18; // 1 SUSHI per block
        uint256 startBlock = block.number + 100; // Start mining 100 blocks from now
        MasterChef masterChef = new MasterChef(sushi, deployer, sushiPerBlock, startBlock);
        console.log("MasterChef deployed at:", address(masterChef));

        // 正确的架构设置：
        // 1. SushiToken由MasterChef控制（用于自动mint挖矿奖励）
        sushi.transferOwnership(address(masterChef));
        console.log("SushiToken ownership transferred to MasterChef");
        
        // 2. MasterChef由deployer控制（生产环境中应该转移给DAO）
        // masterChef.transferOwnership(address(dao)); // 部署DAO后执行
        console.log("MasterChef owned by deployer (transfer to DAO later)");

        // Deploy test tokens
        ERC20Mock tokenA = new ERC20Mock("Token A", "TKNA", 1000000 * 10**18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TKNB", 1000000 * 10**18);
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));

        // Create a trading pair
        address pair = factory.createPair(address(tokenA), address(tokenB));
        console.log("TokenA-TokenB pair created at:", pair);

        // Add the pair to MasterChef for farming (allocation point = 100)
        masterChef.add(100, IERC20(pair), false);
        console.log("TokenA-TokenB pair added to MasterChef for farming");

        vm.stopBroadcast();
    }
} 
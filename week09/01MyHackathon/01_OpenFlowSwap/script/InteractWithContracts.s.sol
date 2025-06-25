// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/dex/SushiRouter.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";
import "../src/mocks/ERC20Mock.sol";
import "../src/interfaces/ISushiPair.sol";

/// @title InteractWithContracts
/// @notice 与已部署的DeFi协议合约交互的示例脚本
contract InteractWithContracts is Script {
    
    // 占位符地址 - 部署后需要更新为实际地址
    address payable constant ROUTER = payable(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    address constant MASTERCHEF = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    address payable constant DAO = payable(0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6);
    address constant TOKEN_A = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant TOKEN_B = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant WETH = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    
    SushiRouter public router;
    MasterChef public masterChef;
    SimpleDAO public dao;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public weth;
    
    function run() external {
        uint256 userPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address user = vm.addr(userPrivateKey);
        
        console.log("=== DeFi Protocol Interaction Demo ===");
        console.log("User address:", user);
        console.log("\nNOTE: Please update contract addresses in the script after deployment!");
        
        _setupContracts();
        
        vm.startBroadcast(userPrivateKey);
        
        // Demo 1: 添加流动性
        _demoAddLiquidity(user);
        
        // Demo 2: 开始流动性挖矿
        _demoStartMining(user);
        
        // Demo 3: Token交换
        _demoTokenSwap(user);
        
        // Demo 4: 收获挖矿奖励
        _demoHarvestRewards(user);
        
        vm.stopBroadcast();
        
        console.log("\n=== Interaction Demo Complete ===");
    }
    
    function _setupContracts() internal {
        router = SushiRouter(ROUTER);
        masterChef = MasterChef(MASTERCHEF);
        dao = SimpleDAO(DAO);
        tokenA = ERC20Mock(TOKEN_A);
        tokenB = ERC20Mock(TOKEN_B);
        weth = ERC20Mock(WETH);
    }
    
    function _demoAddLiquidity(address user) internal {
        console.log("\n--- Demo 1: Adding Liquidity ---");
        
        uint256 amountA = 1000 * 1e18;
        uint256 amountB = 1000 * 1e18;
        
        // 检查余额
        console.log("TokenA balance:", tokenA.balanceOf(user) / 1e18);
        console.log("TokenB balance:", tokenB.balanceOf(user) / 1e18);
        
        // 授权Router
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        // 添加流动性
        (uint256 actualA, uint256 actualB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 300
        );
        
        console.log("Added TokenA:", actualA / 1e18);
        console.log("Added TokenB:", actualB / 1e18);
        console.log("LP tokens received:", liquidity / 1e18);
    }
    
    function _demoStartMining(address user) internal {
        console.log("\n--- Demo 2: Starting Liquidity Mining ---");
        
        // 获取LP代币地址（假设是池子0）
        (IERC20 lpToken,,,) = masterChef.poolInfo(0);
        uint256 lpBalance = lpToken.balanceOf(user);
        
        console.log("LP token balance:", lpBalance / 1e18);
        
        if (lpBalance > 0) {
            // 授权MasterChef
            lpToken.approve(address(masterChef), lpBalance);
            
            // 质押LP代币
            masterChef.deposit(0, lpBalance);
            
            console.log("Staked LP tokens in pool 0");
            console.log("Mining started!");
        }
    }
    
    function _demoTokenSwap(address user) internal {
        console.log("\n--- Demo 3: Token Swap ---");
        
        uint256 swapAmount = 100 * 1e18;
        
        console.log("Swapping", swapAmount / 1e18, "TokenA for TokenB");
        
        // 检查初始余额
        uint256 tokenBBefore = tokenB.balanceOf(user);
        console.log("TokenB before swap:", tokenBBefore / 1e18);
        
        // 授权并交换
        tokenA.approve(address(router), swapAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            user,
            block.timestamp + 300
        );
        
        uint256 tokenBAfter = tokenB.balanceOf(user);
        console.log("TokenB after swap:", tokenBAfter / 1e18);
        console.log("TokenB received:", amounts[1] / 1e18);
    }
    
    function _demoHarvestRewards(address user) internal {
        console.log("\n--- Demo 4: Harvesting Mining Rewards ---");
        
        // 检查待领取奖励
        uint256 pending = masterChef.pendingSushi(0, user);
        console.log("Pending SUSHI rewards:", pending / 1e18);
        
        if (pending > 0) {
            // 提取0数量来只领取奖励
            masterChef.withdraw(0, 0);
            console.log("Harvested SUSHI rewards!");
        }
        else {
            console.log("No pending rewards to harvest");
        }
    }
    
    /// @notice 获取所有合约地址（用于调试）
    function getContractAddresses() external view {
        console.log("=== Contract Addresses ===");
        console.log("Router:", ROUTER);
        console.log("MasterChef:", MASTERCHEF);
        console.log("DAO:", DAO);
        console.log("TokenA:", TOKEN_A);
        console.log("TokenB:", TOKEN_B);
        console.log("WETH:", WETH);
    }
}

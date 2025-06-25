// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";
import "../src/mocks/ERC20Mock.sol";
import "../src/interfaces/ISushiPair.sol";

/// @title DeployToFoundry
/// @notice 完整部署脚本，将所有DeFi协议合约部署到Foundry本地网络
contract DeployToFoundry is Script {
    // 部署的合约实例
    SushiFactory public factory;
    SushiRouter public router;
    SushiToken public sushiToken;
    MasterChef public masterChef;
    SimpleDAO public dao;
    
    // 测试代币
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public weth;
    ERC20Mock public usdc;
    
    // 配置参数
    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18; // 1M tokens
    uint256 public constant SUSHI_PER_BLOCK = 10 * 1e18; // 10 SUSHI per block
    
    // 地址配置
    address public deployer;
    address public devAddress;
    address public treasuryAddress;
    
    function run() external {
        // 获取部署者私钥（从环境变量或默认anvil账户）
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)); // anvil default key
        deployer = vm.addr(deployerPrivateKey);
        
        // 设置开发者和国库地址
        devAddress = vm.envOr("DEV_ADDRESS", deployer);
        treasuryAddress = vm.envOr("TREASURY_ADDRESS", deployer);
        
        console.log("=== Starting DeFi Protocol Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Dev address:", devAddress);
        console.log("Treasury address:", treasuryAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: 部署测试代币
        _deployTestTokens();
        
        // Step 2: 部署核心DeFi合约
        _deployDeFiContracts();
        
        // Step 3: 初始化设置
        _initializeContracts();
        
        // Step 4: 创建交易对
        _createTradingPairs();
        
        // Step 5: 添加流动性挖矿池
        _addLiquidityPools();
        
        // Step 6: 初始代币分发
        _initialTokenDistribution();
        
        // Step 7: 权限设置
        _setupPermissions();
        
        vm.stopBroadcast();
        
        // Step 8: 部署总结
        _deploymentSummary();
    }
    
    function _deployTestTokens() internal {
        console.log("\n--- Step 1: Deploying Test Tokens ---");
        
        tokenA = new ERC20Mock("Token A", "TKA", 18);
        tokenB = new ERC20Mock("Token B", "TKB", 18);
        weth = new ERC20Mock("Wrapped ETH", "WETH", 18);
        usdc = new ERC20Mock("USD Coin", "USDC", 6);
        
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        console.log("WETH deployed at:", address(weth));
        console.log("USDC deployed at:", address(usdc));
    }
    
    function _deployDeFiContracts() internal {
        console.log("\n--- Step 2: Deploying DeFi Contracts ---");
        
        // 部署SushiFactory
        factory = new SushiFactory(deployer);
        console.log("SushiFactory deployed at:", address(factory));
        
        // 部署SushiRouter
        router = new SushiRouter(address(factory), address(weth));
        console.log("SushiRouter deployed at:", address(router));
        
        // 部署SushiToken
        sushiToken = new SushiToken();
        console.log("SushiToken deployed at:", address(sushiToken));
        
        // 部署MasterChef
        masterChef = new MasterChef(
            sushiToken,
            devAddress,
            SUSHI_PER_BLOCK,
            block.number
        );
        console.log("MasterChef deployed at:", address(masterChef));
        
        // 部署SimpleDAO
        dao = new SimpleDAO(sushiToken);
        console.log("SimpleDAO deployed at:", address(dao));
    }
    
    function _initializeContracts() internal {
        console.log("\n--- Step 3: Initializing Contracts ---");

        // 给部署者一些初始SUSHI用于DAO治理（需要先从MasterChef铸造）
        sushiToken.mint(deployer, 10000 * 1e18); // 给部署者一些SUSHI
        sushiToken.mint(devAddress, 5000 * 1e18); // 给开发者一些SUSHI
        
        // 将SUSHI代币的所有权转移给MasterChef
        sushiToken.transferOwnership(address(masterChef));
        console.log("SushiToken ownership transferred to MasterChef");
    }
    
    function _createTradingPairs() internal {
        console.log("\n--- Step 4: Creating Trading Pairs ---");
        
        // 创建主要交易对
        factory.createPair(address(tokenA), address(tokenB));
        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        console.log("TokenA/TokenB pair created at:", pairAB);
        
        factory.createPair(address(tokenA), address(weth));
        address pairAWETH = factory.getPair(address(tokenA), address(weth));
        console.log("TokenA/WETH pair created at:", pairAWETH);
        
        factory.createPair(address(tokenB), address(weth));
        address pairBWETH = factory.getPair(address(tokenB), address(weth));
        console.log("TokenB/WETH pair created at:", pairBWETH);
        
        factory.createPair(address(usdc), address(weth));
        address pairUSDCWETH = factory.getPair(address(usdc), address(weth));
        console.log("USDC/WETH pair created at:", pairUSDCWETH);
    }
    
    function _addLiquidityPools() internal {
        console.log("\n--- Step 5: Adding Liquidity Mining Pools ---");
        
        // 添加主要交易对到MasterChef进行流动性挖矿
        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        masterChef.add(100, IERC20(pairAB), false); // 100 allocation points
        console.log("Added TokenA/TokenB pool (poolId: 0)");
        
        address pairAWETH = factory.getPair(address(tokenA), address(weth));
        masterChef.add(200, IERC20(pairAWETH), false); // 200 allocation points (higher weight)
        console.log("Added TokenA/WETH pool (poolId: 1)");
        
        address pairBWETH = factory.getPair(address(tokenB), address(weth));
        masterChef.add(150, IERC20(pairBWETH), false); // 150 allocation points
        console.log("Added TokenB/WETH pool (poolId: 2)");
        
        address pairUSDCWETH = factory.getPair(address(usdc), address(weth));
        masterChef.add(300, IERC20(pairUSDCWETH), false); // 300 allocation points (highest weight)
        console.log("Added USDC/WETH pool (poolId: 3)");
    }
    
    function _initialTokenDistribution() internal {
        console.log("\n--- Step 6: Initial Token Distribution ---");
        
        // 给部署者铸造初始代币供应量
        tokenA.mint(deployer, INITIAL_SUPPLY);
        tokenB.mint(deployer, INITIAL_SUPPLY);
        weth.mint(deployer, INITIAL_SUPPLY);
        usdc.mint(deployer, INITIAL_SUPPLY / 1e12); // USDC 只有6位小数
        
        console.log("Minted", INITIAL_SUPPLY / 1e18, "TokenA to deployer");
        console.log("Minted", INITIAL_SUPPLY / 1e18, "TokenB to deployer");
        console.log("Minted", INITIAL_SUPPLY / 1e18, "WETH to deployer");
        console.log("Minted", (INITIAL_SUPPLY / 1e12) / 1e6, "USDC to deployer");
        
        
        //masterChef.updatePool(0); // 更新池子以铸造一些SUSHI
    }
    
    function _setupPermissions() internal {
        console.log("\n--- Step 7: Setting up Permissions ---");
        
        // 注意：MasterChef的所有权暂时保留给deployer，这样可以添加更多池子
        // 在生产环境中，应该将MasterChef的所有权转移给DAO
        console.log("MasterChef owner:", masterChef.owner());
        console.log("SushiToken owner:", sushiToken.owner());
        console.log("DAO owner:", dao.owner());
        
        // 可选：将MasterChef所有权转移给DAO（在生产环境中推荐）
        // masterChef.transferOwnership(address(dao));
        // console.log("MasterChef ownership transferred to DAO");
    }
    
    function _deploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Foundry Local");
        console.log("Deployer:", deployer);
        console.log("\n--- Core Contracts ---");
        console.log("SushiFactory:    ", address(factory));
        console.log("SushiRouter:     ", address(router));
        console.log("SushiToken:      ", address(sushiToken));
        console.log("MasterChef:      ", address(masterChef));
        console.log("SimpleDAO:       ", address(dao));
        
        console.log("\n--- Test Tokens ---");
        console.log("TokenA (TKA):    ", address(tokenA));
        console.log("TokenB (TKB):    ", address(tokenB));
        console.log("WETH:            ", address(weth));
        console.log("USDC:            ", address(usdc));
        
        console.log("\n--- Trading Pairs ---");
        console.log("TKA/TKB Pair:    ", factory.getPair(address(tokenA), address(tokenB)));
        console.log("TKA/WETH Pair:   ", factory.getPair(address(tokenA), address(weth)));
        console.log("TKB/WETH Pair:   ", factory.getPair(address(tokenB), address(weth)));
        console.log("USDC/WETH Pair:  ", factory.getPair(address(usdc), address(weth)));
        
        console.log("\n--- Mining Pools ---");
        console.log("Pool 0: TKA/TKB  (100 points)");
        console.log("Pool 1: TKA/WETH (200 points)");
        console.log("Pool 2: TKB/WETH (150 points)");
        console.log("Pool 3: USDC/WETH(300 points)");
        
        console.log("\n--- Configuration ---");
        console.log("SUSHI per block: ", SUSHI_PER_BLOCK / 1e18);
        console.log("Total alloc points:", masterChef.totalAllocPoint());
        
        console.log("\n=== Deployment Complete! ===");
        console.log("\nNext steps:");
        console.log("1. Add liquidity to pairs using SushiRouter");
        console.log("2. Stake LP tokens in MasterChef for mining");
        console.log("3. Use DAO for governance decisions");
        console.log("\nFoundry commands:");
        console.log("- Start anvil: anvil");
        console.log("- Deploy: forge script script/DeployToFoundry.s.sol --rpc-url http://localhost:8545 --broadcast");
    }
}

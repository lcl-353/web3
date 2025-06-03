// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../src/FlashSwap.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/UniswapV2Pair.sol';
import "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import "./mocks/ERC20Mock.sol";
import "../src/UniswapV2Router02.sol";
import "../src/libraries/UniswapV2Library.sol";

contract FlashSwapTest is Test {
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    
    // DEX1
    UniswapV2Factory public factory1;
    UniswapV2Router02 public router1;
    address public pair1;
    
    // DEX2
    UniswapV2Factory public factory2;
    UniswapV2Router02 public router2;
    address public pair2;

    // FlashSwap contract
    FlashSwap public flashSwap;
    
    address public constant WETH = address(0x1);

    function setUp() public {
        // 部署代币
        tokenA = new ERC20Mock("Token A", "TOKA", 18);
        tokenB = new ERC20Mock("Token B", "TOKB", 18);

        // 部署第一个DEX (Factory1 + Router1)
        factory1 = new UniswapV2Factory(address(this));
        router1 = new UniswapV2Router02(address(factory1), WETH);

        // 部署第二个DEX (Factory2 + Router2)
        factory2 = new UniswapV2Factory(address(this));
        router2 = new UniswapV2Router02(address(factory2), WETH);

        // 部署FlashSwap合约，使用DEX1的factory和router
        flashSwap = new FlashSwap(address(factory1), address(router1));

        // 铸造测试代币
        tokenA.mint(address(this), 1000 ether);
        tokenB.mint(address(this), 1000 ether);

        // 给两个router授权
        tokenA.approve(address(router1), type(uint256).max);
        tokenB.approve(address(router1), type(uint256).max);
        tokenA.approve(address(router2), type(uint256).max);
        tokenB.approve(address(router2), type(uint256).max);

        // DEX1: 添加流动性，价格 1A = 2B
        router1.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,  // 100 A
            200 ether,  // 200 B
            0,
            0,
            address(this),
            block.timestamp
        );

        // DEX2: 添加流动性，价格 1A = 1.5B (更好的价格)
        router2.addLiquidity(
            address(tokenA),
            address(tokenB),
            150 ether,  // 150 A
            200 ether,  // 200 B
            0,
            0,
            address(this),
            block.timestamp
        );

        // 获取交易对地址
        pair1 = factory1.getPair(address(tokenA), address(tokenB));
        pair2 = factory2.getPair(address(tokenA), address(tokenB));

        // 输出初始价格
        console.log("DEX1 Initial Price: 1 A = 2 B");
        console.log("DEX2 Initial Price: 1 A = 1.33 B");
    }

    function test_FlashSwap() public {
        // 记录初始余额
        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));
        
        // 获取两个DEX中的实际价格
        (uint256 reserve1A, uint256 reserve1B,) = IUniswapV2Pair(pair1).getReserves();
        (uint256 reserve2A, uint256 reserve2B,) = IUniswapV2Pair(pair2).getReserves();
        
        console.log("DEX1 Reserves - Token A:", reserve1A, "Token B:", reserve1B);
        console.log("DEX2 Reserves - Token A:", reserve2A, "Token B:", reserve2B);
        
        // 执行闪电贷套利
        flashSwap.flashSwap(pair1, address(tokenB));
        
        // 验证套利后余额增加
        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        
        // 输出套利结果
        console.log("Profit in Token A:", finalBalanceA > initialBalanceA ? finalBalanceA - initialBalanceA : 0);
        console.log("Profit in Token B:", finalBalanceB > initialBalanceB ? finalBalanceB - initialBalanceB : 0);
        
        assertTrue(
            finalBalanceA > initialBalanceA || finalBalanceB > initialBalanceB, 
            "Flash swap should be profitable"
        );
    }
}

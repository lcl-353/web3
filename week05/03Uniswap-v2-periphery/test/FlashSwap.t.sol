// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/flashswap.sol";
import "../src/UniswapV2Router02.sol";
import { UniswapV2Factory } from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/WETHMock.sol";

// contract TestToken is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {
//         _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
//     }
// }

contract FlashSwapTest is Test {
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    WETHMock public weth;
    
    UniswapV2Router02 public router1;
    UniswapV2Router02 public router2;
    
    UniswapV2Factory public factory1;
    UniswapV2Factory public factory2;
    
    FlashSwap public flashSwapper;
    
    address public constant ZERO_ADDRESS = address(0);

    function setUp() public {
        // Deploy tokens
        tokenA = new ERC20Mock("Token A", "TKNA");
        tokenB = new ERC20Mock("Token B", "TKNB");
        

        console.log("Token A address:", address(tokenA));
        console.log("Token B address:", address(tokenB));
        // Deploy factories and WETH
        factory1 = new UniswapV2Factory(address(this));
        console.log("Factory 1 address:", address(factory1));
        factory2 = new UniswapV2Factory(address(this));
        console.log("Factory 2 address:", address(factory2));
        weth = new WETHMock();
        console.log("WETH address:", address(weth));

        // Deploy routers
        router1 = new UniswapV2Router02(address(factory1), address(weth));
        router2 = new UniswapV2Router02(address(factory2), address(weth));

        // Deploy FlashSwap contract
        flashSwapper = new FlashSwap(address(factory1), address(router2));

        // Setup initial liquidity with different prices
        setupLiquidity();
    }

    function setupLiquidity() internal {
        // Approve tokens for routers
        tokenA.approve(address(router1), type(uint256).max);
        tokenB.approve(address(router1), type(uint256).max);
        tokenA.approve(address(router2), type(uint256).max);
        tokenB.approve(address(router2), type(uint256).max);

        // Add liquidity to router1 with price ratio 1:2 (1 A = 2 B)
        router1.addLiquidity(
            address(tokenA),
            address(tokenB),
            100000 * 10**18, // 100k tokenA
            200000 * 10**18, // 200k tokenB
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        // Add liquidity to router2 with price ratio 1:1.5 (1 A = 1.5 B)
        router2.addLiquidity(
            address(tokenA),
            address(tokenB),
            100000 * 10**18,  // 100k tokenA
            150000 * 10**18,  // 150k tokenB
            0,
            0,
            address(this),
            block.timestamp + 1
        );
    }

    function testFlashSwap() public {
        // Get pair from factory1
        address pair1 = factory1.getPair(address(tokenA), address(tokenB));
        require(pair1 != address(0), "Pair1 not created");

        // Check initial balances
        uint initialBalanceA = tokenA.balanceOf(address(this));
        uint initialBalanceB = tokenB.balanceOf(address(this));

        console.log("Initial balance A:", initialBalanceA);
        console.log("Initial balance B:", initialBalanceB);

        // Execute flash swap
        flashSwapper.flashSwap(pair1, address(tokenB));

        // Check final balances
        uint finalBalanceA = tokenA.balanceOf(address(this));
        uint finalBalanceB = tokenB.balanceOf(address(this));

        console.log("Final balance A:", finalBalanceA);
        console.log("Final balance B:", finalBalanceB);

        // Verify profit
        require(finalBalanceA > initialBalanceA || finalBalanceB > initialBalanceB, "No profit generated");
    }

    // Additional helper function to check prices
    function testCheckPrices() public view {
        address pair1 = factory1.getPair(address(tokenA), address(tokenB));
        address pair2 = factory2.getPair(address(tokenA), address(tokenB));

        (uint reserve1A, uint reserve1B,) = IUniswapV2Pair(pair1).getReserves();
        (uint reserve2A, uint reserve2B,) = IUniswapV2Pair(pair2).getReserves();

        console.log("Pool 1 - Price of A in terms of B:", (reserve1B * 1e18) / reserve1A);
        console.log("Pool 2 - Price of A in terms of B:", (reserve2B * 1e18) / reserve2A);
    }

    receive() external payable {}
}

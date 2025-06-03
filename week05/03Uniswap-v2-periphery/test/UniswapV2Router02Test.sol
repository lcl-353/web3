// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "../src/UniswapV2Router02.sol";
import { UniswapV2Pair } from "@uniswap/v2-core/contracts/UniswapV2Pair.sol";
import { UniswapV2Factory } from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/WETHMock.sol";

contract UniswapV2Router02Test is Test {
    UniswapV2Router02 public router;
    UniswapV2Factory public factory;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    WETHMock public weth;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // Deploy mock tokens
        tokenA = new ERC20Mock("Token A", "TKNA");
        tokenB = new ERC20Mock("Token B", "TKNB");
        weth = new WETHMock();

        // Deploy factory
        factory = new UniswapV2Factory(address(this));
        
        // Deploy router
        router = new UniswapV2Router02(address(factory), address(weth));

        // Mint tokens to alice
        tokenA.mint(alice, 1000 ether);
        tokenB.mint(alice, 1000 ether);
        
        // Mint tokens to bob
        tokenA.mint(bob, 1000 ether);
        tokenB.mint(bob, 1000 ether);

        // Give ETH to users
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_addLiquidity() public {
        vm.startPrank(alice);

        // Approve router to spend tokens
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
        console.log("Alice's token A balance before adding liquidity:", tokenA.balanceOf(alice));
        console.log("Alice's address:", alice);
        console.log("Bob's address:", bob);
        console.log("Token A's address:", address(tokenA));
        console.log("Token B's address:", address(tokenB));

        //console.logBytes32(INIT_CODE_PAIR_HASH); 
        //console.logBytes(bytecode); 
    
        // 打印字节数组长度
        //console.log("Bytecode length: ", bytecode.length);
        //console.log("INIT_CODE_PAIR_HASH length: ", INIT_CODE_PAIR_HASH.length);


        // Add liquidity
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenB),
            address(tokenA),
            100 ether, // amountADesired
            100 ether, // amountBDesired
            0 ether,  // amountAMin
            0 ether,  // amountBMin
            alice,     // to
            block.timestamp + 1 // deadline
        );

        // Verify results
        assertEq(amountA, 100 ether, "Incorrect amount A");
        assertEq(amountB, 100 ether, "Incorrect amount B");
        assertTrue(liquidity > 0, "No liquidity minted");

        vm.stopPrank();
    }

    function test_addLiquidityETH() public {
        vm.startPrank(alice);

        // Approve router to spend tokens
        tokenA.approve(address(router), 100 ether);

        // Add liquidity ETH
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 100 ether}(
            address(tokenA),
            100 ether, // amountTokenDesired
            95 ether,  // amountTokenMin
            95 ether,  // amountETHMin
            alice,     // to
            block.timestamp + 1 // deadline
        );

        // Verify results
        assertEq(amountToken, 100 ether, "Incorrect token amount");
        assertEq(amountETH, 100 ether, "Incorrect ETH amount");
        assertTrue(liquidity > 0, "No liquidity minted");

        vm.stopPrank();
    }

    function test_swapExactTokensForTokens() public {
        // First add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            95 ether,
            95 ether,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Now bob tries to swap
        vm.startPrank(bob);
        tokenA.approve(address(router), 10 ether);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint bobInitialTokenB = tokenB.balanceOf(bob);

        uint[] memory amounts = router.swapExactTokensForTokens(
            10 ether,    // amountIn
            9 ether,     // amountOutMin
            path,        // path
            bob,         // to
            block.timestamp + 1 // deadline
        );

        uint bobFinalTokenB = tokenB.balanceOf(bob);
        assertTrue(bobFinalTokenB > bobInitialTokenB, "Swap failed");
        assertEq(amounts[0], 10 ether, "Incorrect input amount");
        assertTrue(amounts[1] > 0, "No tokens received");

        vm.stopPrank();
    }

    function test_swapETHForExactTokens() public {
        // First add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        router.addLiquidityETH{value: 100 ether}(
            address(tokenA),
            100 ether,
            95 ether,
            95 ether,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Now bob tries to swap ETH for tokens
        vm.startPrank(bob);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint bobInitialTokenA = tokenA.balanceOf(bob);

        uint[] memory amounts = router.swapETHForExactTokens{value: 10 ether}(
            9 ether,     // amountOut
            path,        // path
            bob,         // to
            block.timestamp + 1 // deadline
        );

        uint bobFinalTokenA = tokenA.balanceOf(bob);
        assertTrue(bobFinalTokenA > bobInitialTokenA, "Swap failed");
        assertTrue(amounts[0] > 0, "No ETH sent");
        assertEq(amounts[1], 9 ether, "Incorrect output amount");

        vm.stopPrank();
    }

    receive() external payable {}
}

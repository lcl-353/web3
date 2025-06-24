// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/dex/SushiPair.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/mocks/ERC20Mock.sol";

contract SushiSwapTest is Test {
    SushiFactory factory;
    SushiRouter router;
    SushiToken sushi;
    MasterChef masterChef;
    ERC20Mock tokenA;
    ERC20Mock tokenB;
    ERC20Mock weth;
    SushiPair pair;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address dev = address(0x3);

    function setUp() public {
        bytes memory bytecode = type(SushiPair).creationCode;
        bytes32 INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(SushiPair).creationCode));

        console.logBytes32(INIT_CODE_PAIR_HASH); 
        //console.logBytes(bytecode); 
    
        //打印字节数组长度
        console.log("Bytecode length: ", bytecode.length);
        console.log("INIT_CODE_PAIR_HASH length: ", INIT_CODE_PAIR_HASH.length);
        // Deploy contracts
        factory = new SushiFactory(dev);
        weth = new ERC20Mock("Wrapped Ether", "WETH", 1000000 * 10**18);
        router = new SushiRouter(address(factory), address(weth));
        sushi = new SushiToken();
        
        uint256 sushiPerBlock = 1 * 10**18;
        uint256 startBlock = block.number + 10;
        masterChef = new MasterChef(sushi, dev, sushiPerBlock, startBlock);
        
        // Transfer ownership of sushi to masterChef
        sushi.transferOwnership(address(masterChef));
        
        // Deploy test tokens
        tokenA = new ERC20Mock("Token A", "TKNA", 1000000 * 10**18);
        tokenB = new ERC20Mock("Token B", "TKNB", 1000000 * 10**18);
        
        // Create pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = SushiPair(pairAddress);
        
        // Add pair to farming
        masterChef.add(100, IERC20(pairAddress), false);
        
        // Give tokens to alice and bob
        tokenA.mint(alice, 1000 * 10**18);
        tokenB.mint(alice, 1000 * 10**18);
        tokenA.mint(bob, 1000 * 10**18);
        tokenB.mint(bob, 1000 * 10**18);
    }

    function testAddLiquidity() public {
        vm.startPrank(alice);
        
        uint256 amountA = 100 * 10**18;
        uint256 amountB = 100 * 10**18;
        
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        (uint256 actualAmountA, uint256 actualAmountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        assertEq(actualAmountA, amountA);
        assertEq(actualAmountB, amountB);
        assertGt(liquidity, 0);
        assertEq(pair.balanceOf(alice), liquidity);
        
        vm.stopPrank();
    }

    function testSwap() public {
        // First add liquidity
        vm.startPrank(alice);
        
        uint256 amountA = 100 * 10**18;
        uint256 amountB = 100 * 10**18;
        
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        vm.stopPrank();
        
        // Now test swap
        vm.startPrank(bob);
        
        uint256 swapAmount = 10 * 10**18;
        tokenA.approve(address(router), swapAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 balanceBefore = tokenB.balanceOf(bob);
        
        router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 balanceAfter = tokenB.balanceOf(bob);
        assertGt(balanceAfter, balanceBefore);
        
        vm.stopPrank();
    }

    function testFarming() public {
        // Add liquidity first
        vm.startPrank(alice);
        
        uint256 amountA = 100 * 10**18;
        uint256 amountB = 100 * 10**18;
        
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        (,, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        // Approve and deposit LP tokens to MasterChef
        pair.approve(address(masterChef), liquidity);
        masterChef.deposit(0, liquidity);
        
        // Fast forward some blocks
        vm.roll(block.number + 100);
        
        // Check pending rewards
        uint256 pending = masterChef.pendingSushi(0, alice);
        assertGt(pending, 0);
        
        // Withdraw and claim rewards
        uint256 sushiBalanceBefore = sushi.balanceOf(alice);
        masterChef.withdraw(0, liquidity);
        uint256 sushiBalanceAfter = sushi.balanceOf(alice);
        
        assertGt(sushiBalanceAfter, sushiBalanceBefore);
        
        vm.stopPrank();
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/dex/SushiPair.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/mocks/ERC20Mock.sol";

/// @title All Functions Test - Complete coverage of MasterChef and SushiRouter
contract AllFunctionsTest is Test {
    SushiFactory factory;
    SushiRouter router;
    SushiToken sushi;
    MasterChef masterChef;
    ERC20Mock tokenA;
    ERC20Mock tokenB;
    ERC20Mock weth;
    SushiPair pairAB;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address dev = address(0x4);

    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;

    function setUp() public {
        // Deploy contracts
        factory = new SushiFactory(dev);
        weth = new ERC20Mock("WETH", "WETH", INITIAL_SUPPLY);
        router = new SushiRouter(address(factory), address(weth));
        sushi = new SushiToken();
        masterChef = new MasterChef(sushi, dev, 1 * 10**18, block.number + 10);
        
        // Transfer ownership
        sushi.transferOwnership(address(masterChef));
        
        // Deploy tokens
        tokenA = new ERC20Mock("Token A", "TKNA", INITIAL_SUPPLY);
        tokenB = new ERC20Mock("Token B", "TKNB", INITIAL_SUPPLY);
        
        // Create pair
        address pairAddr = factory.createPair(address(tokenA), address(tokenB));
        pairAB = SushiPair(pairAddr);
        
        // Give tokens to users
        tokenA.mint(alice, INITIAL_SUPPLY);
        tokenB.mint(alice, INITIAL_SUPPLY);
        tokenA.mint(bob, INITIAL_SUPPLY);
        tokenB.mint(bob, INITIAL_SUPPLY);
        
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        
        vm.roll(block.number + 10);
    }

    // ===== SushiRouter Function Tests =====

    function testRouter_addLiquidity() public {
        vm.startPrank(alice);
        tokenA.approve(address(router), 100e18);
        tokenB.approve(address(router), 100e18);
        
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA), address(tokenB), 100e18, 100e18, 0, 0, alice, block.timestamp + 300
        );
        
        assertGt(liquidity, 0);
        assertEq(amountA, 100e18);
        assertEq(amountB, 100e18);
        vm.stopPrank();
    }

    function testRouter_removeLiquidity() public {
        testRouter_addLiquidity();
        vm.startPrank(alice);
        
        uint liquidity = pairAB.balanceOf(alice);
        pairAB.approve(address(router), liquidity);
        
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA), address(tokenB), liquidity, 0, 0, alice, block.timestamp + 300
        );
        
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        vm.stopPrank();
    }

    function testRouter_swapExactTokensForTokens() public {
        testRouter_addLiquidity();
        vm.startPrank(bob);
        
        tokenA.approve(address(router), 10e18);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            10e18, 0, path, bob, block.timestamp + 300
        );
        
        assertEq(amounts[0], 10e18);
        assertGt(amounts[1], 0);
        vm.stopPrank();
    }

    function testRouter_swapTokensForExactTokens() public {
        testRouter_addLiquidity();
        vm.startPrank(bob);
        
        tokenA.approve(address(router), 20e18);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapTokensForExactTokens(
            5e18, 20e18, path, bob, block.timestamp + 300
        );
        
        assertEq(amounts[1], 5e18);
        assertLe(amounts[0], 20e18);
        vm.stopPrank();
    }

    function testRouter_quote() public {
        uint amountB = router.quote(100e18, 1000e18, 2000e18);
        assertEq(amountB, 200e18);
    }

    function testRouter_getAmountOut() public {
        uint amountOut = router.getAmountOut(100e18, 1000e18, 1000e18);
        assertGt(amountOut, 0);
        assertLt(amountOut, 100e18); // Should be less due to fees
    }

    function testRouter_getAmountIn() public {
        uint amountIn = router.getAmountIn(100e18, 1000e18, 1000e18);
        assertGt(amountIn, 100e18); // Should be more due to fees
    }

    function testRouter_getAmountsOut() public {
        testRouter_addLiquidity();
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.getAmountsOut(10e18, path);
        assertEq(amounts[0], 10e18);
        assertGt(amounts[1], 0);
    }

    function testRouter_getAmountsIn() public {
        testRouter_addLiquidity();
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.getAmountsIn(5e18, path);
        assertGt(amounts[0], 0);
        assertEq(amounts[1], 5e18);
    }

    // ===== MasterChef Function Tests =====

    function testMasterChef_poolLength() public {
        assertEq(masterChef.poolLength(), 0);
    }

    function testMasterChef_add() public {
        vm.startPrank(address(this));
        masterChef.add(100, IERC20(address(pairAB)), false);
        
        assertEq(masterChef.poolLength(), 1);
        assertEq(masterChef.totalAllocPoint(), 100);
        vm.stopPrank();
    }

    function testMasterChef_set() public {
        testMasterChef_add();
        vm.startPrank(address(this));
        
        masterChef.set(0, 200, false);
        (, uint allocPoint,,) = masterChef.poolInfo(0);
        
        assertEq(allocPoint, 200);
        assertEq(masterChef.totalAllocPoint(), 200);
        vm.stopPrank();
    }

    function testMasterChef_pendingSushi() public {
        testMasterChef_add();
        testRouter_addLiquidity();
        
        vm.startPrank(alice);
        uint lpAmount = pairAB.balanceOf(alice);
        pairAB.approve(address(masterChef), lpAmount);
        masterChef.deposit(0, lpAmount);
        
        vm.roll(block.number + 10);
        uint pending = masterChef.pendingSushi(0, alice);
        assertGt(pending, 0);
        vm.stopPrank();
    }

    function testMasterChef_massUpdatePools() public {
        testMasterChef_add();
        masterChef.massUpdatePools();
        
        (,, uint lastRewardBlock,) = masterChef.poolInfo(0);
        assertEq(lastRewardBlock, block.number);
    }

    function testMasterChef_updatePool() public {
        testMasterChef_add();
        masterChef.updatePool(0);
        
        (,, uint lastRewardBlock,) = masterChef.poolInfo(0);
        assertEq(lastRewardBlock, block.number);
    }

    function testMasterChef_deposit() public {
        testMasterChef_add();
        testRouter_addLiquidity();
        
        vm.startPrank(alice);
        uint lpAmount = pairAB.balanceOf(alice);
        pairAB.approve(address(masterChef), lpAmount);
        
        masterChef.deposit(0, lpAmount);
        (uint amount,) = masterChef.userInfo(0, alice);
        
        assertEq(amount, lpAmount);
        vm.stopPrank();
    }

    function testMasterChef_withdraw() public {
        testMasterChef_deposit();
        vm.roll(block.number + 100);
        
        vm.startPrank(alice);
        (uint stakedAmount,) = masterChef.userInfo(0, alice);
        uint sushiBefore = sushi.balanceOf(alice);
        
        masterChef.withdraw(0, stakedAmount / 2);
        
        assertGt(sushi.balanceOf(alice), sushiBefore);
        (uint remaining,) = masterChef.userInfo(0, alice);
        assertEq(remaining, stakedAmount / 2);
        vm.stopPrank();
    }

    function testMasterChef_emergencyWithdraw() public {
        testMasterChef_deposit();
        
        vm.startPrank(alice);
        (uint stakedAmount,) = masterChef.userInfo(0, alice);
        uint lpBefore = pairAB.balanceOf(alice);
        
        masterChef.emergencyWithdraw(0);
        
        assertEq(pairAB.balanceOf(alice), lpBefore + stakedAmount);
        (uint amount, uint rewardDebt) = masterChef.userInfo(0, alice);
        assertEq(amount, 0);
        assertEq(rewardDebt, 0);
        vm.stopPrank();
    }

    function testMasterChef_getMultiplier() public {
        uint multiplier = masterChef.getMultiplier(100, 200);
        assertEq(multiplier, 100);
    }

    function testMasterChef_dev() public {
        address newDev = address(0x999);
        vm.startPrank(dev);
        masterChef.dev(newDev);
        assertEq(masterChef.devaddr(), newDev);
        vm.stopPrank();
    }

    function testMasterChef_updateSushiPerBlock() public {
        vm.startPrank(address(this));
        masterChef.updateSushiPerBlock(2e18);
        assertEq(masterChef.sushiPerBlock(), 2e18);
        vm.stopPrank();
    }

    // ===== Integration Test =====

    function testFullIntegration() public {
        // Setup farming
        vm.startPrank(address(this));
        masterChef.add(100, IERC20(address(pairAB)), false);
        vm.stopPrank();
        
        // Add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100e18);
        tokenB.approve(address(router), 100e18);
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA), address(tokenB), 100e18, 100e18, 0, 0, alice, block.timestamp + 300
        );
        
        // Farm
        pairAB.approve(address(masterChef), liquidity);
        masterChef.deposit(0, liquidity);
        
        vm.roll(block.number + 100);
        uint pending = masterChef.pendingSushi(0, alice);
        assertGt(pending, 0);
        
        uint sushiBefore = sushi.balanceOf(alice);
        masterChef.withdraw(0, liquidity);
        assertGt(sushi.balanceOf(alice), sushiBefore);
        
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/dex/SushiPair.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/mocks/ERC20Mock.sol";

/// @title Comprehensive Test Suite for MasterChef and SushiRouter
/// @notice Tests all functions in both MasterChef.sol and SushiRouter.sol
contract ComprehensiveTest is Test {
    SushiFactory factory;
    SushiRouter router;
    SushiToken sushi;
    MasterChef masterChef;
    ERC20Mock tokenA;
    ERC20Mock tokenB;
    ERC20Mock tokenC;
    ERC20Mock weth;
    SushiPair pairAB;
    SushiPair pairAC;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address dev = address(0x4);
    address feeReceiver = address(0x5);

    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant SUSHI_PER_BLOCK = 1 * 10**18;

    function setUp() public {
        // Deploy contracts
        factory = new SushiFactory(feeReceiver);
        weth = new ERC20Mock("Wrapped Ether", "WETH", INITIAL_SUPPLY);
        router = new SushiRouter(address(factory), address(weth));
        sushi = new SushiToken();
        
        uint256 startBlock = block.number + 10;
        masterChef = new MasterChef(sushi, dev, SUSHI_PER_BLOCK, startBlock);
        
        // Transfer ownership of sushi to masterChef
        sushi.transferOwnership(address(masterChef));
        
        // Deploy test tokens
        tokenA = new ERC20Mock("Token A", "TKNA", INITIAL_SUPPLY);
        tokenB = new ERC20Mock("Token B", "TKNB", INITIAL_SUPPLY);
        tokenC = new ERC20Mock("Token C", "TKNC", INITIAL_SUPPLY);
        
        // Create pairs
        address pairABAddress = factory.createPair(address(tokenA), address(tokenB));
        address pairACAddress = factory.createPair(address(tokenA), address(tokenC));
        
        pairAB = SushiPair(pairABAddress);
        pairAC = SushiPair(pairACAddress);
        
        // Distribute tokens to users
        _distributeTokens();
        
        // Move to start block
        vm.roll(startBlock);
    }

    function _distributeTokens() internal {
        address[3] memory users = [alice, bob, carol];
        
        for (uint i = 0; i < users.length; i++) {
            tokenA.mint(users[i], INITIAL_SUPPLY);
            tokenB.mint(users[i], INITIAL_SUPPLY);
            tokenC.mint(users[i], INITIAL_SUPPLY);
            weth.mint(users[i], INITIAL_SUPPLY);
            
            // Give some ETH to users
            vm.deal(users[i], 100 ether);
        }
    }

    // ==================== SushiRouter Tests ====================

    /// @notice Test addLiquidity function
    function testSushiRouter_AddLiquidity() public {
        vm.startPrank(alice);
        
        uint256 amountA = 100 * 10**18;
        uint256 amountB = 200 * 10**18;
        
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
        assertEq(pairAB.balanceOf(alice), liquidity);
        
        vm.stopPrank();
    }

    /// @notice Test removeLiquidity function
    function testSushiRouter_RemoveLiquidity() public {
        // First add liquidity
        testSushiRouter_AddLiquidity();
        
        vm.startPrank(alice);
        
        uint256 liquidity = pairAB.balanceOf(alice);
        pairAB.approve(address(router), liquidity);
        
        uint256 balanceABefore = tokenA.balanceOf(alice);
        uint256 balanceBBefore = tokenB.balanceOf(alice);
        
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertGt(tokenA.balanceOf(alice), balanceABefore);
        assertGt(tokenB.balanceOf(alice), balanceBBefore);
        
        vm.stopPrank();
    }

    /// @notice Test swapExactTokensForTokens function
    function testSushiRouter_SwapExactTokensForTokens() public {
        // First add liquidity
        testSushiRouter_AddLiquidity();
        
        vm.startPrank(bob);
        
        uint256 swapAmount = 10 * 10**18;
        tokenA.approve(address(router), swapAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 balanceBefore = tokenB.balanceOf(bob);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 300
        );
        
        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertGt(tokenB.balanceOf(bob), balanceBefore);
        
        vm.stopPrank();
    }

    /// @notice Test swapTokensForExactTokens function
    function testSushiRouter_SwapTokensForExactTokens() public {
        // First add liquidity
        testSushiRouter_AddLiquidity();
        
        vm.startPrank(bob);
        
        uint256 amountOut = 5 * 10**18;
        uint256 amountInMax = 20 * 10**18;
        tokenA.approve(address(router), amountInMax);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 balanceBefore = tokenB.balanceOf(bob);
        
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            bob,
            block.timestamp + 300
        );
        
        assertEq(amounts[amounts.length - 1], amountOut);
        assertLe(amounts[0], amountInMax);
        assertEq(tokenB.balanceOf(bob), balanceBefore + amountOut);
        
        vm.stopPrank();
    }

    /// @notice Test quote, getAmountOut, getAmountIn functions
    function testSushiRouter_QuoteFunctions() public {
        // Test quote function
        uint256 amountA = 100 * 10**18;
        uint256 reserveA = 1000 * 10**18;
        uint256 reserveB = 2000 * 10**18;
        
        uint256 amountB = router.quote(amountA, reserveA, reserveB);
        assertEq(amountB, amountA * reserveB / reserveA);
        
        // Test getAmountOut
        uint256 amountIn = 100 * 10**18;
        uint256 amountOut = router.getAmountOut(amountIn, reserveA, reserveB);
        assertGt(amountOut, 0);
        
        // Test getAmountIn
        uint256 amountOutDesired = 100 * 10**18;
        uint256 amountInRequired = router.getAmountIn(amountOutDesired, reserveA, reserveB);
        assertGt(amountInRequired, 0);
    }

    /// @notice Test getAmountsOut and getAmountsIn functions
    function testSushiRouter_GetAmounts() public {
        // First add liquidity to create reserves
        testSushiRouter_AddLiquidity();
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        
        // Add liquidity for B-C pair
        vm.startPrank(alice);
        tokenB.approve(address(router), 100 * 10**18);
        tokenC.approve(address(router), 100 * 10**18);
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            100 * 10**18,
            100 * 10**18,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();
        
        // Test getAmountsOut
        uint256 amountIn = 10 * 10**18;
        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        assertEq(amountsOut[0], amountIn);
        assertGt(amountsOut[1], 0);
        assertGt(amountsOut[2], 0);
        
        // Test getAmountsIn
        uint256 amountOut = 5 * 10**18;
        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path);
        assertGt(amountsIn[0], 0);
        assertGt(amountsIn[1], 0);
        assertEq(amountsIn[2], amountOut);
    }

    // ==================== MasterChef Tests ====================

    /// @notice Test poolLength function
    function testMasterChef_PoolLength() public {
        assertEq(masterChef.poolLength(), 0);
    }

    /// @notice Test add function
    function testMasterChef_Add() public {
        vm.startPrank(address(this)); // Contract deployer is owner
        
        masterChef.add(100, IERC20(address(pairAB)), false);
        assertEq(masterChef.poolLength(), 1);
        
        (IERC20 lpToken, uint256 allocPoint, , ) = masterChef.poolInfo(0);
        assertEq(address(lpToken), address(pairAB));
        assertEq(allocPoint, 100);
        assertEq(masterChef.totalAllocPoint(), 100);
        
        vm.stopPrank();
    }

    /// @notice Test set function
    function testMasterChef_Set() public {
        testMasterChef_Add();
        
        vm.startPrank(address(this));
        
        masterChef.set(0, 200, false);
        
        (, uint256 allocPoint, , ) = masterChef.poolInfo(0);
        assertEq(allocPoint, 200);
        assertEq(masterChef.totalAllocPoint(), 200);
        
        vm.stopPrank();
    }

    /// @notice Test pendingSushi function
    function testMasterChef_PendingSushi() public {
        // Setup: Add pool and liquidity
        testMasterChef_Add();
        testSushiRouter_AddLiquidity();
        
        vm.startPrank(alice);
        
        uint256 lpAmount = pairAB.balanceOf(alice);
        pairAB.approve(address(masterChef), lpAmount);
        masterChef.deposit(0, lpAmount);
        
        // Fast forward blocks
        vm.roll(block.number + 10);
        
        uint256 pending = masterChef.pendingSushi(0, alice);
        assertGt(pending, 0);
        
        vm.stopPrank();
    }

    /// @notice Test updatePool function
    function testMasterChef_UpdatePool() public {
        testMasterChef_Add();
        
        uint256 blockBefore = block.number;
        masterChef.updatePool(0);
        
        (, , uint256 lastRewardBlock, ) = masterChef.poolInfo(0);
        assertEq(lastRewardBlock, blockBefore);
    }

    /// @notice Test massUpdatePools function
    function testMasterChef_MassUpdatePools() public {
        // Add multiple pools
        vm.startPrank(address(this));
        masterChef.add(100, IERC20(address(pairAB)), false);
        masterChef.add(200, IERC20(address(pairAC)), false);
        vm.stopPrank();
        
        masterChef.massUpdatePools();
        
        // Verify both pools were updated
        (, , uint256 lastRewardBlock1, ) = masterChef.poolInfo(0);
        (, , uint256 lastRewardBlock2, ) = masterChef.poolInfo(1);
        
        assertEq(lastRewardBlock1, block.number);
        assertEq(lastRewardBlock2, block.number);
    }

    /// @notice Test deposit function
    function testMasterChef_Deposit() public {
        // Setup
        testMasterChef_Add();
        testSushiRouter_AddLiquidity();
        
        vm.startPrank(alice);
        
        uint256 lpAmount = pairAB.balanceOf(alice);
        pairAB.approve(address(masterChef), lpAmount);
        
        uint256 balanceBefore = pairAB.balanceOf(alice);
        masterChef.deposit(0, lpAmount);
        
        assertEq(pairAB.balanceOf(alice), balanceBefore - lpAmount);
        
        (uint256 amount, ) = masterChef.userInfo(0, alice);
        assertEq(amount, lpAmount);
        
        vm.stopPrank();
    }

    /// @notice Test withdraw function
    function testMasterChef_Withdraw() public {
        // Setup: Deposit first
        testMasterChef_Deposit();
        
        // Fast forward to accumulate rewards
        vm.roll(block.number + 100);
        
        vm.startPrank(alice);
        
        (uint256 stakedAmount, ) = masterChef.userInfo(0, alice);
        uint256 withdrawAmount = stakedAmount / 2;
        
        uint256 sushiBalanceBefore = sushi.balanceOf(alice);
        uint256 lpBalanceBefore = pairAB.balanceOf(alice);
        
        masterChef.withdraw(0, withdrawAmount);
        
        // Check LP tokens returned
        assertEq(pairAB.balanceOf(alice), lpBalanceBefore + withdrawAmount);
        
        // Check SUSHI rewards received
        assertGt(sushi.balanceOf(alice), sushiBalanceBefore);
        
        // Check remaining staked amount
        (uint256 remainingAmount, ) = masterChef.userInfo(0, alice);
        assertEq(remainingAmount, stakedAmount - withdrawAmount);
        
        vm.stopPrank();
    }

    /// @notice Test emergencyWithdraw function
    function testMasterChef_EmergencyWithdraw() public {
        // Setup: Deposit first
        testMasterChef_Deposit();
        
        vm.startPrank(alice);
        
        (uint256 stakedAmount, ) = masterChef.userInfo(0, alice);
        uint256 lpBalanceBefore = pairAB.balanceOf(alice);
        uint256 sushiBalanceBefore = sushi.balanceOf(alice);
        
        masterChef.emergencyWithdraw(0);
        
        // Check all LP tokens returned
        assertEq(pairAB.balanceOf(alice), lpBalanceBefore + stakedAmount);
        
        // Check no SUSHI rewards received (emergency withdraw)
        assertEq(sushi.balanceOf(alice), sushiBalanceBefore);
        
        // Check user info reset
        (uint256 amount, uint256 rewardDebt) = masterChef.userInfo(0, alice);
        assertEq(amount, 0);
        assertEq(rewardDebt, 0);
        
        vm.stopPrank();
    }

    /// @notice Test getMultiplier function
    function testMasterChef_GetMultiplier() public {
        uint256 fromBlock = 100;
        uint256 toBlock = 200;
        uint256 multiplier = masterChef.getMultiplier(fromBlock, toBlock);
        assertEq(multiplier, toBlock - fromBlock);
    }

    /// @notice Test dev function
    function testMasterChef_Dev() public {
        address newDev = address(0x999);
        
        vm.startPrank(dev);
        masterChef.dev(newDev);
        assertEq(masterChef.devaddr(), newDev);
        vm.stopPrank();
        
        // Test unauthorized access
        vm.startPrank(alice);
        vm.expectRevert("dev: wut?");
        masterChef.dev(alice);
        vm.stopPrank();
    }

    /// @notice Test updateSushiPerBlock function
    function testMasterChef_UpdateSushiPerBlock() public {
        uint256 newSushiPerBlock = 2 * 10**18;
        
        vm.startPrank(address(this)); // Contract deployer is owner
        masterChef.updateSushiPerBlock(newSushiPerBlock);
        assertEq(masterChef.sushiPerBlock(), newSushiPerBlock);
        vm.stopPrank();
        
        // Test unauthorized access
        vm.startPrank(alice);
        vm.expectRevert();
        masterChef.updateSushiPerBlock(newSushiPerBlock);
        vm.stopPrank();
    }

    // ==================== Integration Tests ====================

    /// @notice Test complete DeFi flow
    function testIntegration_CompleteFlow() public {
        // 1. Add farming pool
        vm.startPrank(address(this));
        masterChef.add(100, IERC20(address(pairAB)), false);
        vm.stopPrank();
        
        // 2. Add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 * 10**18);
        tokenB.approve(address(router), 100 * 10**18);
        
        (, , uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 * 10**18,
            100 * 10**18,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        // 3. Stake LP tokens
        pairAB.approve(address(masterChef), liquidity);
        masterChef.deposit(0, liquidity);
        
        // 4. Fast forward time
        vm.roll(block.number + 100);
        
        // 5. Check pending rewards
        uint256 pending = masterChef.pendingSushi(0, alice);
        assertGt(pending, 0);
        
        // 6. Withdraw and claim rewards
        uint256 sushiBalanceBefore = sushi.balanceOf(alice);
        masterChef.withdraw(0, liquidity);
        assertGt(sushi.balanceOf(alice), sushiBalanceBefore);
        
        // 7. Remove liquidity
        pairAB.approve(address(router), liquidity);
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        vm.stopPrank();
    }

    /// @notice Test error cases and edge conditions
    function testErrorCases() public {
        // Test deposit to non-existent pool
        vm.startPrank(alice);
        vm.expectRevert();
        masterChef.deposit(999, 100);
        vm.stopPrank();
        
        // Test withdraw more than deposited
        testMasterChef_Deposit();
        vm.startPrank(alice);
        vm.expectRevert("withdraw: not good");
        masterChef.withdraw(0, 999 * 10**18);
        vm.stopPrank();
        
        // Test router with expired deadline
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 * 10**18);
        tokenB.approve(address(router), 100 * 10**18);
        vm.expectRevert("SushiRouter: EXPIRED");
        router.addLiquidity(
            address(tokenA), address(tokenB), 100 * 10**18, 100 * 10**18, 0, 0, alice, block.timestamp - 1
        );
        vm.stopPrank();
    }
} 
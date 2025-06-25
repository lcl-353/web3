// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/dex/SushiFactory.sol";
import "../src/dex/SushiRouter.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";
import "../src/mocks/ERC20Mock.sol";
import "../src/interfaces/ISushiPair.sol";

/// @title ComprehensiveDeFiFlowTest
/// @notice Comprehensive test covering the complete DeFi flow:
/// 1. Add liquidity and start liquidity mining
/// 2. DAO governance changes mining parameters  
/// 3. Check mining rewards after parameter changes
/// 4. Perform token swaps
contract ComprehensiveDeFiFlowTest is Test {
    SushiFactory public factory;
    SushiRouter public router;
    SushiToken public sushiToken;
    MasterChef public masterChef;
    SimpleDAO public dao;
    
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public weth;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public dev = makeAddr("dev");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant SUSHI_PER_BLOCK = 10 * 1e18;
    
    ISushiPair public lpToken;
    uint256 public poolId;
    
    event LiquidityAdded(address indexed user, uint256 liquidity);
    event MiningStarted(address indexed user, uint256 amount);
    event ParameterChanged(uint256 oldValue, uint256 newValue);
    event RewardsHarvested(address indexed user, uint256 amount);
    event SwapExecuted(address indexed user, uint256 amountIn, uint256 amountOut);

    function setUp() public {
        console.log("=== Setting up Comprehensive DeFi Flow Test ===");
        
        // Deploy mock tokens
        tokenA = new ERC20Mock("Token A", "TKA", 18);
        tokenB = new ERC20Mock("Token B", "TKB", 18);
        weth = new ERC20Mock("Wrapped ETH", "WETH", 18);
        
        // Deploy core contracts
        factory = new SushiFactory(address(this));
        router = new SushiRouter(address(factory), address(weth));
        sushiToken = new SushiToken();
        masterChef = new MasterChef(sushiToken, dev, SUSHI_PER_BLOCK, block.number);
        dao = new SimpleDAO(sushiToken);
        
        // Transfer SUSHI ownership to MasterChef
        sushiToken.transferOwnership(address(masterChef));
        
        // Create LP pair
        factory.createPair(address(tokenA), address(tokenB));
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        lpToken = ISushiPair(pairAddress);
        
        // Setup initial balances
        _setupInitialBalances();
        
        // Add LP pool to MasterChef
        masterChef.add(100, IERC20(address(lpToken)), false);
        poolId = 0; // First pool
        
        console.log("Setup completed successfully");
        console.log("TokenA address:", address(tokenA));
        console.log("TokenB address:", address(tokenB));
        console.log("LP Token address:", address(lpToken));
        console.log("Pool ID:", poolId);
    }
    
    function _setupInitialBalances() internal {
        // Mint tokens to users
        tokenA.mint(alice, INITIAL_SUPPLY);
        tokenB.mint(alice, INITIAL_SUPPLY);
        tokenA.mint(bob, INITIAL_SUPPLY);
        tokenB.mint(bob, INITIAL_SUPPLY);
        tokenA.mint(charlie, INITIAL_SUPPLY);
        tokenB.mint(charlie, INITIAL_SUPPLY);
        
        // Mint some SUSHI to users for DAO voting (simulate early distribution)
        vm.prank(address(masterChef));
        sushiToken.mint(alice, 5000 * 1e18);
        vm.prank(address(masterChef));
        sushiToken.mint(bob, 3000 * 1e18);
        vm.prank(address(masterChef));
        sushiToken.mint(charlie, 2000 * 1e18);
        
        // Delegate voting power
        vm.prank(alice);
        sushiToken.delegate(alice);
        vm.prank(bob);
        sushiToken.delegate(bob);
        vm.prank(charlie);
        sushiToken.delegate(charlie);
    }

    /// @notice Test the complete DeFi flow
    function testComprehensiveDeFiFlow() public {
        console.log("\n=== STARTING COMPREHENSIVE DEFI FLOW TEST ===");
        
        // Step 1: Add liquidity and start mining
        _step1_AddLiquidityAndStartMining();
        
        // Step 2: DAO governance changes mining parameters
        _step2_DAOChangeMiningParameters();
        
        // Step 3: Check mining rewards after parameter changes
        _step3_CheckMiningRewardsAfterChange();
        
        // Step 4: Perform token swaps
        _step4_PerformTokenSwaps();
        
        console.log("\n=== COMPREHENSIVE DEFI FLOW TEST COMPLETED SUCCESSFULLY ===");
    }
    
    function _step1_AddLiquidityAndStartMining() internal {
        console.log("\n--- Step 1: Add Liquidity and Start Mining ---");
        
        uint256 amountA = 1000 * 1e18;
        uint256 amountB = 1000 * 1e18;
        
        vm.startPrank(alice);
        
        // Approve router to spend tokens
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        // Add liquidity
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
        
        console.log("Added liquidity - AmountA:", actualAmountA);
        console.log("Added liquidity - AmountB:", actualAmountB);
        console.log("LP tokens received:", liquidity);
        
        emit LiquidityAdded(alice, liquidity);
        
        // Approve MasterChef to spend LP tokens
        lpToken.approve(address(masterChef), liquidity);
        
        // Deposit LP tokens for mining
        masterChef.deposit(poolId, liquidity);
        console.log("Deposited LP tokens for mining:", liquidity);
        
        emit MiningStarted(alice, liquidity);
        
        vm.stopPrank();
        
        // Mine some blocks to accumulate rewards
        vm.roll(block.number + 10);
        
        uint256 pendingRewards = masterChef.pendingSushi(poolId, alice);
        console.log("Pending SUSHI rewards after 10 blocks:", pendingRewards);
        
        assertTrue(liquidity > 0, "Should have received LP tokens");
        assertTrue(pendingRewards > 0, "Should have pending rewards");
    }
    
    function _step2_DAOChangeMiningParameters() internal {
        console.log("\n--- Step 2: DAO Changes Mining Parameters ---");
        
        uint256 oldSushiPerBlock = masterChef.sushiPerBlock();
        uint256 newSushiPerBlock = oldSushiPerBlock * 2; // Double the rewards
        
        console.log("Current SUSHI per block:", oldSushiPerBlock);
        console.log("Proposed new SUSHI per block:", newSushiPerBlock);
        
        // Prepare proposal data
        bytes memory proposalData = abi.encodeWithSelector(
            MasterChef.updateSushiPerBlock.selector,
            newSushiPerBlock
        );
        
        // Create proposal
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(masterChef),
            0,
            proposalData,
            "Increase SUSHI rewards per block from 10 to 20"
        );
        
        console.log("Created proposal ID:", proposalId);
        
        // Wait for voting delay
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        // Vote on proposal
        vm.prank(alice);
        dao.castVote(proposalId, 1); // Vote FOR
        
        vm.prank(bob);
        dao.castVote(proposalId, 1); // Vote FOR
        
        vm.prank(charlie);
        dao.castVote(proposalId, 1); // Vote FOR
        
        console.log("All users voted FOR the proposal");
        
        // Wait for voting period to end
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Check if proposal succeeded
        SimpleDAO.ProposalState state = dao.state(proposalId);
        console.log("Proposal state:", uint256(state));
        assertEq(uint256(state), uint256(SimpleDAO.ProposalState.Succeeded), "Proposal should succeed");
        
        // Queue proposal for execution
        dao.queue(proposalId);
        console.log("Proposal queued for execution");
        
        // Wait for execution delay
        vm.warp(block.timestamp + dao.EXECUTION_DELAY() + 1);
        
        // Transfer MasterChef ownership to DAO for execution
        masterChef.transferOwnership(address(dao));
        
        // Execute proposal
        dao.execute(proposalId);
        console.log("Proposal executed successfully");
        
        // Verify the change
        uint256 updatedSushiPerBlock = masterChef.sushiPerBlock();
        console.log("Updated SUSHI per block:", updatedSushiPerBlock);
        
        emit ParameterChanged(oldSushiPerBlock, updatedSushiPerBlock);
        
        assertEq(updatedSushiPerBlock, newSushiPerBlock, "SUSHI per block should be updated");
    }
    
    function _step3_CheckMiningRewardsAfterChange() internal {
        console.log("\n--- Step 3: Check Mining Rewards After Parameter Change ---");
        
        uint256 pendingBefore = masterChef.pendingSushi(poolId, alice);
        console.log("Pending rewards before mining more blocks:", pendingBefore);
        
        // Mine 10 more blocks with increased rewards
        vm.roll(block.number + 10);
        
        uint256 pendingAfter = masterChef.pendingSushi(poolId, alice);
        console.log("Pending rewards after 10 more blocks (increased rate):", pendingAfter);
        
        // Harvest rewards
        vm.prank(alice);
        masterChef.withdraw(poolId, 0); // Withdraw 0 to just claim rewards
        
        uint256 sushiBalance = sushiToken.balanceOf(alice);
        console.log("SUSHI balance after harvest:", sushiBalance);
        
        emit RewardsHarvested(alice, sushiBalance);
        
        assertTrue(pendingAfter > pendingBefore, "Rewards should increase with higher rate");
        assertTrue(sushiBalance > 0, "Should have harvested SUSHI rewards");
    }
    
    function _step4_PerformTokenSwaps() internal {
        console.log("\n--- Step 4: Perform Token Swaps ---");
        
        // Setup swap user (bob)
        vm.startPrank(bob);
        
        uint256 swapAmountIn = 100 * 1e18;
        uint256 tokenABalanceBefore = tokenA.balanceOf(bob);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(bob);
        
        console.log("Bob's TokenA balance before swap:", tokenABalanceBefore);
        console.log("Bob's TokenB balance before swap:", tokenBBalanceBefore);
        
        // Approve router for swap
        tokenA.approve(address(router), swapAmountIn);
        
        // Prepare swap path
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Get expected output
        uint256[] memory amountsOut = router.getAmountsOut(swapAmountIn, path);
        uint256 expectedAmountOut = amountsOut[1];
        console.log("Expected TokenB output:", expectedAmountOut);
        
        // Perform swap
        uint256[] memory actualAmounts = router.swapExactTokensForTokens(
            swapAmountIn,
            expectedAmountOut * 95 / 100, // 5% slippage tolerance
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 actualAmountOut = actualAmounts[1];
        console.log("Actual TokenB received:", actualAmountOut);
        
        // Check balances after swap
        uint256 tokenABalanceAfter = tokenA.balanceOf(bob);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(bob);
        
        console.log("Bob's TokenA balance after swap:", tokenABalanceAfter);
        console.log("Bob's TokenB balance after swap:", tokenBBalanceAfter);
        
        emit SwapExecuted(bob, swapAmountIn, actualAmountOut);
        
        vm.stopPrank();
        
        // Verify swap results
        assertEq(tokenABalanceAfter, tokenABalanceBefore - swapAmountIn, "TokenA should decrease by input amount");
        assertTrue(tokenBBalanceAfter > tokenBBalanceBefore, "TokenB should increase");
        assertTrue(actualAmountOut > 0, "Should receive TokenB output");
        
        // Perform reverse swap to test liquidity
        console.log("\n--- Performing Reverse Swap ---");
        
        vm.startPrank(charlie);
        
        uint256 reverseSwapAmount = 50 * 1e18;
        tokenB.approve(address(router), reverseSwapAmount);
        
        address[] memory reversePath = new address[](2);
        reversePath[0] = address(tokenB);
        reversePath[1] = address(tokenA);
        
        uint256[] memory reverseAmountsOut = router.getAmountsOut(reverseSwapAmount, reversePath);
        console.log("Expected TokenA from reverse swap:", reverseAmountsOut[1]);
        
        router.swapExactTokensForTokens(
            reverseSwapAmount,
            reverseAmountsOut[1] * 95 / 100,
            reversePath,
            charlie,
            block.timestamp + 300
        );
        
        console.log("Reverse swap completed successfully");
        
        vm.stopPrank();
    }
    
    /// @notice Test emergency scenarios
    function testEmergencyScenarios() public {
        console.log("\n=== Testing Emergency Scenarios ===");
        
        // Setup liquidity first
        _step1_AddLiquidityAndStartMining();
        
        // Test emergency withdrawal
        vm.prank(alice);
        masterChef.emergencyWithdraw(poolId);
        
        uint256 lpBalance = lpToken.balanceOf(alice);
        console.log("LP tokens after emergency withdrawal:", lpBalance);
        
        assertTrue(lpBalance > 0, "Should have recovered LP tokens");
    }
    
    /// @notice Test DAO proposal rejection scenario
    function testDAOProposalRejection() public {
        console.log("\n=== Testing DAO Proposal Rejection ===");
        
        // Create a proposal
        bytes memory proposalData = abi.encodeWithSelector(
            MasterChef.updateSushiPerBlock.selector,
            1 * 1e18 // Reduce rewards
        );
        
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(masterChef),
            0,
            proposalData,
            "Reduce SUSHI rewards per block"
        );
        
        // Wait for voting delay
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        // Vote against the proposal
        vm.prank(alice);
        dao.castVote(proposalId, 0); // Vote AGAINST
        
        vm.prank(bob);
        dao.castVote(proposalId, 0); // Vote AGAINST
        
        // Wait for voting period to end
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Check if proposal was defeated
        SimpleDAO.ProposalState state = dao.state(proposalId);
        console.log("Rejected proposal state:", uint256(state));
        
        assertTrue(
            state == SimpleDAO.ProposalState.Defeated,
            "Proposal should be defeated"
        );
    }
    
    /// @notice Helper function to log current system state
    function logSystemState() public view {
        console.log("\n=== Current System State ===");
        console.log("Total SUSHI supply:", sushiToken.totalSupply());
        console.log("SUSHI per block:", masterChef.sushiPerBlock());
        console.log("Total pools:", masterChef.poolLength());
        console.log("DAO proposal count:", dao.proposalCount());
        console.log("LP token total supply:", lpToken.totalSupply());
    }
}
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

/// @title SimplifiedDeFiFlowTest
/// @notice Simplified test covering the complete DeFi flow with smaller functions
contract SimplifiedDeFiFlowTest is Test {
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
    
    function setUp() public {
        console.log("=== Setting up Simplified DeFi Flow Test ===");
        
        _deployContracts();
        _setupPairs();
        _setupBalances();
        _addPool();
        
        console.log("Setup completed successfully");
    }
    
    function _deployContracts() internal {
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
        //masterChef.transferOwnership(address(dao)); // 先add添加池子，后面再transferOwnership，通过dao来管理
    }
    
    function _setupPairs() internal {
        // Create LP pair
        factory.createPair(address(tokenA), address(tokenB));
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        lpToken = ISushiPair(pairAddress);
    }
    
    function _setupBalances() internal {
        // Mint tokens to users
        tokenA.mint(alice, INITIAL_SUPPLY);
        tokenB.mint(alice, INITIAL_SUPPLY);
        tokenA.mint(bob, INITIAL_SUPPLY);
        tokenB.mint(bob, INITIAL_SUPPLY);
        tokenA.mint(charlie, INITIAL_SUPPLY);
        tokenB.mint(charlie, INITIAL_SUPPLY);
        
        // Mint SUSHI for DAO voting
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
    
    function _addPool() internal {
        // Add LP pool to MasterChef
        masterChef.add(100, IERC20(address(lpToken)), false);
        poolId = 0;
    }

    /// @notice Test the complete flow in sequence
    function testCompleteDeFiFlow() public {
        console.log("\n=== TESTING COMPLETE DEFI FLOW ===");
        
        // Step 1: Add liquidity and mining
        console.log("\n--- Step 1: Add Liquidity and Start Mining ---");
        _addLiquidityAndStartMining();
        
        // Step 2: DAO changes parameters
        console.log("\n--- Step 2: DAO Changes Mining Parameters ---");
        _daoChangeMiningParameters();
        
        // Step 3: Check rewards after change
        console.log("\n--- Step 3: Check Rewards After Change ---");
        _checkRewardsAfterChange();
        
        // Step 4: Perform swaps
        console.log("\n--- Step 4: Perform Token Swaps ---");
        _performTokenSwaps();
        
        console.log("\n=== COMPLETE DEFI FLOW TEST SUCCESSFUL ===");
    }
    
    function _addLiquidityAndStartMining() internal {
        uint256 amountA = 1000 * 1e18;
        uint256 amountB = 1000 * 1e18;
        
        vm.startPrank(alice);
        
        // Approve and add liquidity
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
        
        console.log("LP tokens received:", liquidity);
        
        // Start mining
        lpToken.approve(address(masterChef), liquidity);
        masterChef.deposit(poolId, liquidity);
        
        vm.stopPrank();
        
        // Mine blocks
        vm.roll(block.number + 10);
        
        uint256 pending = masterChef.pendingSushi(poolId, alice);
        console.log("Pending SUSHI after 10 blocks:", pending);
        
        assertTrue(liquidity > 0, "Should have LP tokens");
        assertTrue(pending > 0, "Should have pending rewards");
    }
    
    function _daoChangeMiningParameters() internal {
        uint256 oldRate = masterChef.sushiPerBlock();
        uint256 newRate = oldRate * 2;
        
        console.log("Old SUSHI per block:", oldRate);
        console.log("New SUSHI per block:", newRate);
        
        // Create proposal
        bytes memory data = abi.encodeWithSelector(
            MasterChef.updateSushiPerBlock.selector,
            newRate,
            true
        );
        
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(masterChef),
            0,
            data,
            "Double SUSHI rewards"
        );
        
        // Vote and execute
        _voteAndExecuteProposal(proposalId);
        
        // Verify
        uint256 updated = masterChef.sushiPerBlock();
        console.log("Updated SUSHI per block:", updated);
        assertEq(updated, newRate, "Rate should be updated");
    }
    
    function _checkRewardsAfterChange() internal {
        uint256 pendingBefore = masterChef.pendingSushi(poolId, alice);
        console.log("Pending before mining:", pendingBefore);
        
        // Mine more blocks
        vm.roll(block.number + 10);
        
        uint256 pendingAfter = masterChef.pendingSushi(poolId, alice);
        console.log("Pending after mining:", pendingAfter);
        
        // Harvest
        vm.prank(alice);
        masterChef.withdraw(poolId, 0);
        
        uint256 balance = sushiToken.balanceOf(alice);
        console.log("SUSHI balance after harvest:", balance);
        
        assertTrue(pendingAfter > pendingBefore, "Rewards should increase");
        assertTrue(balance > 0, "Should have harvested SUSHI");
    }
    
    function _performTokenSwaps() internal {
        uint256 swapAmount = 100 * 1e18;
        
        vm.startPrank(bob);
        
        uint256 balanceBefore = tokenB.balanceOf(bob);
        console.log("TokenB balance before swap:", balanceBefore);
        
        // Approve and swap
        tokenA.approve(address(router), swapAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 balanceAfter = tokenB.balanceOf(bob);
        console.log("TokenB balance after swap:", balanceAfter);
        console.log("TokenB received:", amounts[1]);
        
        vm.stopPrank();
        
        assertTrue(balanceAfter > balanceBefore, "Should receive TokenB");
        assertTrue(amounts[1] > 0, "Should swap successfully");
    }
    
    function _voteAndExecuteProposal(uint256 proposalId) internal {
        // Wait for voting delay
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        // Vote
        vm.prank(alice);
        dao.castVote(proposalId, 1); // FOR
        vm.prank(bob);
        dao.castVote(proposalId, 1); // FOR
        vm.prank(charlie);
        dao.castVote(proposalId, 1); // FOR
        
        // Wait for voting period
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Queue
        dao.queue(proposalId);
        
        // Wait for execution delay
        vm.warp(block.timestamp + dao.EXECUTION_DELAY() + 1);
        
        // Transfer ownership and execute
        masterChef.transferOwnership(address(dao));
        dao.execute(proposalId);
    }
    
    /// @notice Test emergency withdrawal
    function testEmergencyWithdrawal() public {
        _addLiquidityAndStartMining();
        
        console.log("\n=== Testing Emergency Withdrawal ===");
        
        vm.prank(alice);
        masterChef.emergencyWithdraw(poolId);
        
        uint256 lpBalance = lpToken.balanceOf(alice);
        console.log("LP tokens after emergency withdrawal:", lpBalance);
        
        assertTrue(lpBalance > 0, "Should recover LP tokens");
    }
    
    /// @notice Test proposal rejection
    function testProposalRejection() public {
        console.log("\n=== Testing Proposal Rejection ===");
        
        bytes memory data = abi.encodeWithSelector(
            MasterChef.updateSushiPerBlock.selector,
            1 * 1e18,
            true
        );
        
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(masterChef),
            0,
            data,
            "Reduce rewards"
        );
        
        // Wait and vote against
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        vm.prank(alice);
        dao.castVote(proposalId, 0); // AGAINST
        vm.prank(bob);
        dao.castVote(proposalId, 0); // AGAINST
        
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        SimpleDAO.ProposalState state = dao.state(proposalId);
        assertTrue(state == SimpleDAO.ProposalState.Defeated, "Should be defeated");
    }

    /// @notice Test Step 1: Add liquidity and start mining
    function testStep1_AddLiquidityAndMining() public {
        console.log("\n=== Step 1: Add Liquidity and Start Mining ===");
        _addLiquidityAndStartMining();
    }
    
    /// @notice Test Step 2: DAO changes mining parameters
    function testStep2_DAOChangeParameters() public {
        // First setup liquidity
        _addLiquidityAndStartMining();
        
        console.log("\n=== Step 2: DAO Changes Mining Parameters ===");
        _daoChangeMiningParameters();
    }
    
    /// @notice Test Step 3: Check rewards after parameter change
    function testStep3_CheckRewardsAfterChange() public {
        // Setup and change parameters
        _addLiquidityAndStartMining();
        _daoChangeMiningParameters();
        
        console.log("\n=== Step 3: Check Rewards After Change ===");
        _checkRewardsAfterChange();
    }
    
    /// @notice Test Step 4: Perform swaps
    function testStep4_PerformSwaps() public {
        // Setup liquidity first
        _addLiquidityAndStartMining();
        
        console.log("\n=== Step 4: Perform Token Swaps ===");
        _performTokenSwaps();
    }
}
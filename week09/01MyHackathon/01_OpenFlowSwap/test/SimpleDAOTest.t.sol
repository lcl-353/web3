// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";

contract SimpleDAOTest is Test {
    SushiToken public sushiToken;
    SimpleDAO public dao;
    MasterChef public masterChef;

    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public {
        deployer = address(this);
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        // Deploy contracts
        sushiToken = new SushiToken();
        dao = new SimpleDAO(sushiToken);
        
        masterChef = new MasterChef(
            sushiToken,
            deployer,
            1 * 10**18, // 1 SUSHI per block
            block.number + 100
        );

        // Setup initial state
        _setupInitialTokens();
        
        // Transfer ownership to DAO
        sushiToken.transferOwnership(address(dao));
        masterChef.transferOwnership(address(dao));
    }

    function _setupInitialTokens() internal {
        // Mint tokens to users for testing
        sushiToken.mint(alice, 10000 * 10**18); // 10k SUSHI
        sushiToken.mint(bob, 5000 * 10**18); // 5k SUSHI
        sushiToken.mint(charlie, 500 * 10**18); // 500 SUSHI (reduced for quorum test)

        // Delegate voting power to themselves
        vm.prank(alice);
        sushiToken.delegate(alice);
        
        vm.prank(bob);
        sushiToken.delegate(bob);
        
        vm.prank(charlie);
        sushiToken.delegate(charlie);
    }

    /// @notice Test DAO deployment and initial setup
    function testDAODeployment() public {
        assertEq(address(dao.sushiToken()), address(sushiToken));
        assertEq(dao.VOTING_DELAY(), 1 days);
        assertEq(dao.VOTING_PERIOD(), 1 weeks);
        assertEq(dao.EXECUTION_DELAY(), 2 days);
        assertEq(dao.PROPOSAL_THRESHOLD(), 1000 * 10**18);
        assertEq(dao.QUORUM_PERCENTAGE(), 4);
        
        // Check ownership transfer
        assertEq(sushiToken.owner(), address(dao));
        assertEq(masterChef.owner(), address(dao));
    }

    /// @notice Test proposal creation
    function testProposalCreation() public {
        // Create a proposal to mint more tokens
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            alice,
            1000 * 10**18
        );
        
        string memory description = "Mint 1000 SUSHI tokens to Alice";

        vm.prank(alice); // Alice has enough tokens for proposal threshold
        uint256 proposalId = dao.propose(
            address(sushiToken),
            0,
            data,
            description
        );
        
        assertEq(proposalId, 1);
        assertEq(dao.proposalCount(), 1);
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Pending));
    }

    /// @notice Test proposal creation fails with insufficient voting power
    function testProposalCreationFailsInsufficientPower() public {
        address noVotingPower = address(0x999);
        
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            alice,
            1000 * 10**18
        );
        
        vm.prank(noVotingPower);
        vm.expectRevert("SimpleDAO: insufficient voting power");
        dao.propose(address(sushiToken), 0, data, "Test proposal");
    }

    /// @notice Test voting on proposals
    function testVoting() public {
        // Create proposal
        uint256 proposalId = _createTestProposal();
        
        // Fast forward to voting period
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Active));

        // Vote on proposal
        vm.prank(alice);
        dao.castVote(proposalId, 1); // Vote FOR (1)
        
        vm.prank(bob);
        dao.castVote(proposalId, 1); // Vote FOR (1)
        
        vm.prank(charlie);
        dao.castVote(proposalId, 0); // Vote AGAINST (0)

        // Check vote records
        assertTrue(dao.hasVoted(proposalId, alice));
        assertTrue(dao.hasVoted(proposalId, bob));
        assertTrue(dao.hasVoted(proposalId, charlie));
        
        assertEq(dao.getVote(proposalId, alice), 1);
        assertEq(dao.getVote(proposalId, bob), 1);
        assertEq(dao.getVote(proposalId, charlie), 0);
    }

    /// @notice Test voting fails when already voted
    function testDoubleVotingFails() public {
        uint256 proposalId = _createTestProposal();
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        vm.prank(alice);
        dao.castVote(proposalId, 1);
        
        vm.prank(alice);
        vm.expectRevert("SimpleDAO: already voted");
        dao.castVote(proposalId, 0);
    }

    /// @notice Test proposal states
    function testProposalStates() public {
        uint256 proposalId = _createTestProposal();
        
        // Initially pending
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Pending));
        
        // Active during voting period
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Active));
        
        // Vote to make it succeed
        vm.prank(alice);
        dao.castVote(proposalId, 1); // 10k votes FOR
        
        vm.prank(bob);
        dao.castVote(proposalId, 1); // 5k votes FOR
        
        // End voting period
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Succeeded));
    }

    /// @notice Test proposal execution
    function testProposalExecution() public {
        uint256 proposalId = _createTestProposal();
        
        // Vote and make it succeed
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        vm.prank(alice);
        dao.castVote(proposalId, 1);
        
        vm.prank(bob);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Queue proposal
        dao.queue(proposalId);
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Queued));

        // Fast forward past execution delay
        vm.warp(block.timestamp + dao.EXECUTION_DELAY() + 1);
        
        uint256 aliceBalanceBefore = sushiToken.balanceOf(alice);
        
        // Execute proposal
        dao.execute(proposalId);
        
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Executed));
        assertEq(sushiToken.balanceOf(alice), aliceBalanceBefore + 1000 * 10**18);
    }

    /// @notice Test quorum requirements
    function testQuorumRequirements() public {
        uint256 proposalId = _createTestProposal();
        
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        // Only Charlie votes (500 tokens), which is less than 4% quorum
        vm.prank(charlie);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Should be defeated due to lack of quorum
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Defeated));
    }

    /// @notice Test proposal cancellation
    function testProposalCancellation() public {
        uint256 proposalId = _createTestProposal();
        
        // Alice (proposer) can cancel
        vm.prank(alice);
        dao.cancel(proposalId);
        
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Canceled));
    }

    /// @notice Test owner can cancel any proposal
    function testOwnerCanCancel() public {
        uint256 proposalId = _createTestProposal();
        
        // DAO owner can cancel
        dao.cancel(proposalId);
        
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Canceled));
    }

    /// @notice Test unauthorized cancellation fails
    function testUnauthorizedCancellationFails() public {
        uint256 proposalId = _createTestProposal();
        
        vm.prank(bob); // Bob is not proposer or owner
        vm.expectRevert("SimpleDAO: unauthorized");
        dao.cancel(proposalId);
    }

    /// @notice Test MasterChef governance integration
    function testMasterChefGovernance() public {
        // Create proposal to update MasterChef parameters
        bytes memory data = abi.encodeWithSignature(
            "updateSushiPerBlock(uint256)",
            2 * 10**18 // Update to 2 SUSHI per block
        );
        
        string memory description = "Update SUSHI emission to 2 tokens per block";

        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(masterChef),
            0,
            data,
            description
        );
        
        // Vote and execute
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        vm.prank(alice);
        dao.castVote(proposalId, 1);
        
        vm.prank(bob);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        dao.queue(proposalId);
        vm.warp(block.timestamp + dao.EXECUTION_DELAY() + 1);
        dao.execute(proposalId);
        
        assertEq(masterChef.sushiPerBlock(), 2 * 10**18);
    }

    /// @notice Test get proposal details
    function testGetProposalDetails() public {
        uint256 proposalId = _createTestProposal();
        
        (
            address proposer,
            address target,
            uint256 value,
            bytes memory data,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool executed,
            bool canceled
        ) = dao.getProposal(proposalId);
        
        assertEq(proposer, alice);
        assertEq(target, address(sushiToken));
        assertEq(value, 0);
        assertEq(description, "Mint 1000 SUSHI tokens to Alice");
        assertEq(forVotes, 0); // No votes yet
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
        assertFalse(executed);
        assertFalse(canceled);
    }

    /// @notice Test quorum calculation
    function testQuorumCalculation() public {
        uint256 totalSupply = sushiToken.totalSupply();
        uint256 expectedQuorum = (totalSupply * 4) / 100; // 4%
        
        assertEq(dao.quorum(), expectedQuorum);
    }

    /// @notice Test DAO can receive ETH
    function testDAOReceiveETH() public {
        uint256 amount = 1 ether;
        
        vm.deal(alice, amount);
        vm.prank(alice);
        (bool success,) = address(dao).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(dao).balance, amount);
    }

    /// @notice Test proposal expiration
    function testProposalExpiration() public {
        uint256 proposalId = _createTestProposal();
        
        // Vote and queue
        vm.warp(block.timestamp + dao.VOTING_DELAY() + 1);
        
        vm.prank(alice);
        dao.castVote(proposalId, 1);
        
        vm.prank(bob);
        dao.castVote(proposalId, 1);
        
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        dao.queue(proposalId);
        
        // Wait for expiration (14 days after execution time)
        vm.warp(block.timestamp + dao.EXECUTION_DELAY() + 14 days + 1);
        
        assertEq(uint256(dao.state(proposalId)), uint256(SimpleDAO.ProposalState.Expired));
    }

    /// @notice Helper function to create a test proposal
    function _createTestProposal() internal returns (uint256) {
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            alice,
            1000 * 10**18
        );
        
        string memory description = "Mint 1000 SUSHI tokens to Alice";

        vm.prank(alice);
        return dao.propose(address(sushiToken), 0, data, description);
    }
} 
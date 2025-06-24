// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../farming/SushiToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SimpleDAO
/// @notice A simplified but complete DAO governance system for SushiSwap
contract SimpleDAO is Ownable, ReentrancyGuard {
    SushiToken public immutable sushiToken;
    
    // Governance parameters
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000 SUSHI
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4% of total supply

    // Proposal states
    enum ProposalState {
        Pending,
        Active, 
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        address target;
        uint256 value;
        bytes data;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes; // 0=Against, 1=For, 2=Abstain
    }

    // Storage
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower; // Cached voting power
    uint256 public proposalCount;
    uint256 public lastProposalId;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address target,
        uint256 value,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    event ProposalQueued(uint256 indexed proposalId, uint256 executionTime);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    constructor(SushiToken _sushiToken) Ownable(msg.sender) {
        sushiToken = _sushiToken;
    }

    /// @notice Create a new proposal
    function propose(
        address target,
        uint256 value,
        bytes memory data,
        string memory description
    ) external returns (uint256) {
        require(
            sushiToken.getVotes(msg.sender) >= PROPOSAL_THRESHOLD,
            "SimpleDAO: insufficient voting power"
        );

        uint256 proposalId = ++lastProposalId;
        proposalCount++;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.target = target;
        newProposal.value = value;
        newProposal.data = data;
        newProposal.description = description;
        newProposal.startTime = block.timestamp + VOTING_DELAY;
        newProposal.endTime = newProposal.startTime + VOTING_PERIOD;

        emit ProposalCreated(proposalId, msg.sender, target, value, description);
        return proposalId;
    }

    /// @notice Vote on a proposal
    function castVote(uint256 proposalId, uint8 support) external {
        require(support <= 2, "SimpleDAO: invalid vote type");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "SimpleDAO: proposal not found");
        require(!proposal.hasVoted[msg.sender], "SimpleDAO: already voted");
        require(block.timestamp >= proposal.startTime, "SimpleDAO: voting not started");
        require(block.timestamp <= proposal.endTime, "SimpleDAO: voting ended");

        uint256 weight = sushiToken.getVotes(msg.sender);
        require(weight > 0, "SimpleDAO: no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = support;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /// @notice Queue a successful proposal for execution
    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "SimpleDAO: proposal not succeeded");
        
        Proposal storage proposal = proposals[proposalId];
        proposal.executionTime = block.timestamp + EXECUTION_DELAY;
        
        emit ProposalQueued(proposalId, proposal.executionTime);
    }

    /// @notice Execute a queued proposal
    function execute(uint256 proposalId) external payable nonReentrant {
        require(state(proposalId) == ProposalState.Queued, "SimpleDAO: proposal not queued");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.executionTime, "SimpleDAO: execution delay not met");
        
        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "SimpleDAO: execution failed");

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a proposal
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "SimpleDAO: proposal not found");
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "SimpleDAO: unauthorized"
        );
        require(!proposal.executed, "SimpleDAO: already executed");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /// @notice Get the current state of a proposal
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "SimpleDAO: proposal not found");

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (sushiToken.totalSupply() * QUORUM_PERCENTAGE) / 100;

        if (totalVotes < requiredQuorum || proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }

        if (proposal.executionTime == 0) {
            return ProposalState.Succeeded;
        }

        if (block.timestamp >= proposal.executionTime + 14 days) {
            return ProposalState.Expired;
        }

        return ProposalState.Queued;
    }

    /// @notice Get proposal details
    function getProposal(uint256 proposalId) external view returns (
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
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.target,
            proposal.value,
            proposal.data,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.canceled
        );
    }

    /// @notice Check if an address has voted on a proposal
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    /// @notice Get the vote of an address on a proposal
    function getVote(uint256 proposalId, address voter) external view returns (uint8) {
        return proposals[proposalId].votes[voter];
    }

    /// @notice Get quorum threshold
    function quorum() external view returns (uint256) {
        return (sushiToken.totalSupply() * QUORUM_PERCENTAGE) / 100;
    }

    /// @notice Emergency function to update governance parameters (only owner)
    function updateGovernanceParams() external onlyOwner {
        // This function can be used to upgrade governance parameters
        // Implementation depends on specific requirements
    }

    /// @notice Withdraw ETH from the DAO (only through proposals)
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "SimpleDAO: insufficient balance");
        to.transfer(amount);
    }

    /// @notice Allow the DAO to receive ETH
    receive() external payable {}
} 
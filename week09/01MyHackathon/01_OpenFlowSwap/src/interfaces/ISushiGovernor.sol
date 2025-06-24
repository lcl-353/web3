// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ISushiGovernor
/// @notice Interface for the SushiSwap DAO Governor contract
interface ISushiGovernor {
    /// @notice Possible states that a proposal may be in
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

    /// @notice Emitted when a proposal is created
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice Emitted when a vote has been cast on a proposal
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    /// @notice Emitted when a proposal has been queued in the timelock
    event ProposalQueued(uint256 proposalId, uint256 eta);

    /// @notice Emitted when a proposal has been executed in the timelock
    event ProposalExecuted(uint256 proposalId);

    /// @notice Emitted when a proposal has been canceled
    event ProposalCanceled(uint256 proposalId);
} 
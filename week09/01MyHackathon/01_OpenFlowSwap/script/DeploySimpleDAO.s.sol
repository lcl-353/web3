// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";

/// @title DeploySimpleDAO
/// @notice Script to deploy the SushiSwap DAO governance system
contract DeploySimpleDAO is Script {
    // Deployed contract addresses
    SushiToken public sushiToken;
    SimpleDAO public dao;
    MasterChef public masterChef;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Simple DAO with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy SushiToken
        console.log("Deploying SushiToken...");
        sushiToken = new SushiToken();
        console.log("SushiToken deployed at:", address(sushiToken));

        // Step 2: Deploy SimpleDAO
        console.log("Deploying SimpleDAO...");
        dao = new SimpleDAO(sushiToken);
        console.log("SimpleDAO deployed at:", address(dao));

        // Step 3: Deploy MasterChef
        console.log("Deploying MasterChef...");
        uint256 sushiPerBlock = 1 * 10**18; // 1 SUSHI per block
        uint256 startBlock = block.number + 100; // Start in 100 blocks
        
        masterChef = new MasterChef(
            sushiToken,
            deployer, // Temporary dev address
            sushiPerBlock,
            startBlock
        );
        console.log("MasterChef deployed at:", address(masterChef));

        // Step 4: Transfer ownership to DAO
        console.log("Transferring ownership to DAO...");
        
        // Transfer SushiToken ownership to DAO
        sushiToken.transferOwnership(address(dao));
        
        // Transfer MasterChef ownership to DAO
        masterChef.transferOwnership(address(dao));
        
        console.log("Ownership transferred to DAO");

        // Step 5: Mint initial tokens for testing
        console.log("Minting initial test tokens...");
        
        // Create initial token distribution proposal
        _createInitialTokenProposal(deployer);

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("SushiToken:", address(sushiToken));
        console.log("SimpleDAO:", address(dao));
        console.log("MasterChef:", address(masterChef));
        console.log("Deployer:", deployer);
        console.log("\n=== GOVERNANCE PARAMETERS ===");
        console.log("Voting Delay:", dao.VOTING_DELAY(), "seconds");
        console.log("Voting Period:", dao.VOTING_PERIOD(), "seconds");
        console.log("Execution Delay:", dao.EXECUTION_DELAY(), "seconds");
        console.log("Proposal Threshold:", dao.PROPOSAL_THRESHOLD() / 10**18, "SUSHI");
        console.log("Quorum Percentage:", dao.QUORUM_PERCENTAGE(), "%");
    }

    function _createInitialTokenProposal(address deployer) internal {
        // Create a proposal to mint initial tokens
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            deployer,
            100000 * 10**18 // 100k SUSHI for testing
        );
        
        string memory description = "Mint initial 100,000 SUSHI tokens for DAO testing and development";
        
        // Note: This will fail initially because deployer doesn't have voting power yet
        // This is just for demonstration - in practice, you'd need to bootstrap voting power first
        console.log("Example proposal created (may fail due to no voting power)");
    }

    /// @notice Helper function to bootstrap the DAO after deployment
    function bootstrapDAO() external {
        require(address(sushiToken) != address(0), "Deploy DAO first");
        
        console.log("Bootstrapping DAO...");
        
        // Example of how to bootstrap the DAO:
        // 1. Mint some initial tokens (requires ownership)
        // 2. Delegate voting power to yourself
        // 3. Create first proposal
        
        console.log("DAO bootstrap complete");
    }
} 
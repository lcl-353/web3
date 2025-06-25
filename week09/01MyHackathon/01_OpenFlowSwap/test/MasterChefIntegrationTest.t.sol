// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/farming/SushiToken.sol";
import "../src/farming/MasterChef.sol";
import "../src/governance/SimpleDAO.sol";
// Simplified test - no need for DEX contracts
import "../src/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MasterChef Integration Test
/// @notice 测试完整的挖矿流程和权限架构  
contract MasterChefIntegrationTest is Test {
    SushiToken public sushiToken;
    MasterChef public masterChef;
    SimpleDAO public dao;
    
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public lpToken; // 使用ERC20Mock作为LP代币简化测试

    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    address public dev;

    function setUp() public {
        deployer = address(this);
        alice = address(0x1);
        bob = address(0x2);
        dev = address(0x3);

        // Deploy core contracts
        sushiToken = new SushiToken();
        
        // Deploy MasterChef with dev rewards
        uint256 sushiPerBlock = 1 * 10**18; // 1 SUSHI per block
        uint256 startBlock = block.number + 10;
        masterChef = new MasterChef(sushiToken, dev, sushiPerBlock, startBlock);
        
        // Deploy DAO
        dao = new SimpleDAO(sushiToken);
        
        // Deploy test tokens and LP token (simplified for testing)
        tokenA = new ERC20Mock("Token A", "TOKA", 1000000 * 10**18);
        tokenB = new ERC20Mock("Token B", "TOKB", 1000000 * 10**18);
        lpToken = new ERC20Mock("LP Token", "LP", 1000000 * 10**18);
        
        // Add LP token to MasterChef for farming (before transferring ownership)
        masterChef.add(100, IERC20(address(lpToken)), false);
        
        // 设置正确的权限架构 (在添加池之后)
        sushiToken.transferOwnership(address(masterChef)); // SushiToken → MasterChef
        masterChef.transferOwnership(address(dao));         // MasterChef → DAO
        
        // Give users LP tokens for testing
        lpToken.transfer(alice, 1000 * 10**18);
        lpToken.transfer(bob, 500 * 10**18);
    }

    /// @notice Test the correct architecture setup
    function testArchitectureSetup() public {
        // Verify ownership structure
        assertEq(sushiToken.owner(), address(masterChef), "SushiToken should be owned by MasterChef");
        assertEq(masterChef.owner(), address(dao), "MasterChef should be owned by DAO");
        
        // Verify MasterChef can mint (this is the critical test)
        uint256 balanceBefore = sushiToken.balanceOf(alice);
        vm.prank(address(masterChef));
        sushiToken.mint(alice, 100 * 10**18);
        assertEq(sushiToken.balanceOf(alice), balanceBefore + 100 * 10**18, "MasterChef should be able to mint");
        
        console.log("Architecture correctly set up");
    }

    /// @notice Test automatic SUSHI minting during farming
    function testAutomaticMinting() public {
        vm.roll(masterChef.startBlock());
        
        uint256 pid = 0;
        uint256 depositAmount = 100 * 10**18;
        
        // Record initial balances
        uint256 totalSupplyBefore = sushiToken.totalSupply();
        uint256 devBalanceBefore = sushiToken.balanceOf(dev);
        
        // Alice deposits (should trigger updatePool and mint)
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), depositAmount);
        masterChef.deposit(pid, depositAmount);
        vm.stopPrank();
        
        // Mine blocks and trigger another update
        vm.roll(block.number + 5);
        
        // Bob deposits (should trigger more minting)
        vm.startPrank(bob);
        lpToken.approve(address(masterChef), depositAmount / 2);
        masterChef.deposit(pid, depositAmount / 2);
        vm.stopPrank();
        
        // Verify automatic minting occurred
        uint256 totalSupplyAfter = sushiToken.totalSupply();
        uint256 devBalanceAfter = sushiToken.balanceOf(dev);
        
        assertGt(totalSupplyAfter, totalSupplyBefore, "Total supply should have increased");
        assertGt(devBalanceAfter, devBalanceBefore, "Dev should have received rewards");
        
        console.log("Automatic minting verified");
    }

    /// @notice Test DAO governance over MasterChef parameters
    function testDAOGovernanceOverMasterChef() public {
        // Initial emission rate
        uint256 initialRate = masterChef.sushiPerBlock();
        assertEq(initialRate, 1 * 10**18, "Initial rate should be 1 SUSHI per block");
        
        // Only DAO should be able to update parameters
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        masterChef.updateSushiPerBlock(2 * 10**18, true);
        
        // DAO can update parameters
        vm.prank(address(dao));
        masterChef.updateSushiPerBlock(2 * 10**18, true);
        
        assertEq(masterChef.sushiPerBlock(), 2 * 10**18, "Emission rate should be updated");
        
        console.log("DAO governance working");
    }

    /// @notice Test that only MasterChef can mint SushiToken
    function testSushiTokenPermissions() public {
        // DAO cannot directly mint SushiToken
        vm.prank(address(dao));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(dao)));
        sushiToken.mint(alice, 1000 * 10**18);
        
        // Only MasterChef can mint
        uint256 balanceBefore = sushiToken.balanceOf(alice);
        vm.prank(address(masterChef));
        sushiToken.mint(alice, 1000 * 10**18);
        assertEq(sushiToken.balanceOf(alice), balanceBefore + 1000 * 10**18, "MasterChef should be able to mint");
        
        console.log("SushiToken permissions correctly enforced");
    }
}

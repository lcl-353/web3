// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool, KKToken} from "../src/StakingPool.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    uint256 public constant INITIAL_ETH_BALANCE = 100 ether;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    function setUp() public {
        // 部署KK Token合约
        kkToken = new KKToken();
        
        // 部署StakingPool合约
        stakingPool = new StakingPool(address(kkToken));
        
        // 设置质押池地址到KK Token
        kkToken.setStakingPool(address(stakingPool));
        
        // 给测试账户分配ETH
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);
        vm.deal(user3, INITIAL_ETH_BALANCE);
        
        console.log("KKToken deployed at:", address(kkToken));
        console.log("StakingPool deployed at:", address(stakingPool));
    }
    
    function testInitialState() public {
        // 检查初始状态
        assertEq(stakingPool.totalStaked(), 0);
        assertEq(stakingPool.lastRewardBlock(), block.number);
        assertEq(stakingPool.accRewardPerShare(), 0);
        assertEq(address(stakingPool.kkToken()), address(kkToken));
        assertEq(kkToken.totalSupply(), 0);
        assertEq(kkToken.stakingPool(), address(stakingPool));
    }
    
    function testStakeSingleUser() public {
        uint256 stakeAmount = 1 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        
        // 检查事件触发
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, stakeAmount);
        
        stakingPool.stake{value: stakeAmount}();
        vm.stopPrank();
        
        // 检查状态更新
        assertEq(stakingPool.totalStaked(), stakeAmount);
        assertEq(address(stakingPool).balance, stakeAmount);
        
        // 检查用户质押信息
        (uint256 amount) = 
            stakingPool.balanceOf(user1);
        assertEq(amount, stakeAmount);
    }
    
    function testStakeZeroAmount() public {
        vm.startPrank(user1);
        
        // 尝试质押0 ETH应该失败
        vm.expectRevert("Cannot stake 0 ETH");
        stakingPool.stake{value: 0}();
        
        vm.stopPrank();
    }
    
    function testMultipleUsersStaking() public {
        uint256 stakeAmount1 = 1 ether;
        uint256 stakeAmount2 = 2 ether;
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount1}();
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: stakeAmount2}();
        
        // 检查总质押量
        assertEq(stakingPool.totalStaked(), stakeAmount1 + stakeAmount2);
        assertEq(address(stakingPool).balance, stakeAmount1 + stakeAmount2);
        
        // 检查用户质押信息
        (uint256 amount1) = stakingPool.balanceOf(user1);
        (uint256 amount2) = stakingPool.balanceOf(user2);
        
        assertEq(amount1, stakeAmount1);
        assertEq(amount2, stakeAmount2);
    }
    
    function testRewardCalculation() public {
        uint256 stakeAmount = 1 ether;
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟时间过去（挖矿几个区块）
        uint256 blocksToMine = 10;
        vm.roll(block.number + blocksToMine);
        
        // 检查待领取奖励
        uint256 expectedReward = blocksToMine * REWARD_PER_BLOCK;
        uint256 earned = stakingPool.earned(user1);
        
        assertEq(earned, expectedReward);
    }
    
    function testMultipleUsersRewardDistribution() public {
        uint256 stakeAmount1 = 1 ether;
        uint256 stakeAmount2 = 3 ether;
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount1}();
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: stakeAmount2}();
        
        // 模拟时间过去
        uint256 blocksToMine = 20;
        vm.roll(block.number + blocksToMine);
        
        // 计算期望奖励（按质押比例分配）
        uint256 totalStaked = stakeAmount1 + stakeAmount2;
        uint256 totalReward = blocksToMine * REWARD_PER_BLOCK;
        
        uint256 expectedReward1 = (totalReward * stakeAmount1) / totalStaked;
        uint256 expectedReward2 = (totalReward * stakeAmount2) / totalStaked;
        
        // 检查奖励分配
        assertEq(stakingPool.earned(user1), expectedReward1);
        assertEq(stakingPool.earned(user2), expectedReward2);
        
        // 验证总奖励等于期望值
        assertEq(expectedReward1 + expectedReward2, totalReward);
    }
    
    function testClaimReward() public {
        uint256 stakeAmount = 2 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟时间过去
        uint256 blocksToMine = 5;
        vm.roll(block.number + blocksToMine);
        
        uint256 expectedReward = blocksToMine * REWARD_PER_BLOCK;
        
        // 检查事件触发
        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(user1, expectedReward);
        
        // 领取奖励
        stakingPool.claim();
        
        vm.stopPrank();
        
        // 检查KK Token余额
        assertEq(kkToken.balanceOf(user1), expectedReward);
        
        // 检查质押金额未变
        (uint256 amount) = stakingPool.balanceOf(user1);
        assertEq(amount, stakeAmount);
        
        // 检查奖励已清零
        assertEq(stakingPool.earned(user1), 0);
    }
    
    function testClaimRewardWithoutStaking() public {
        vm.startPrank(user1);
        
        // 没有质押就尝试领取奖励
        vm.expectRevert("No staked amount");
        stakingPool.claim();
        
        vm.stopPrank();
    }
    
    function testClaimRewardWithNoPending() public {
        uint256 stakeAmount = 1 ether;
        
        vm.startPrank(user1);
        
        // 质押但不等待时间
        stakingPool.stake{value: stakeAmount}();
        
        // 尝试领取奖励（没有待领取的奖励）
        vm.expectRevert("No pending reward");
        stakingPool.claim();
        
        vm.stopPrank();
    }
    
    function testUnstakePartial() public {
        uint256 stakeAmount = 5 ether;
        uint256 unstakeAmount = 2 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟时间过去
        uint256 blocksToMine = 8;
        vm.roll(block.number + blocksToMine);
        
        uint256 expectedReward = blocksToMine * REWARD_PER_BLOCK;
        uint256 initialBalance = user1.balance;
        
        // 检查事件触发
        // vm.expectEmit(true, false, false, true);
        // emit Unstaked(user1, unstakeAmount);
        
        // vm.expectEmit(true, false, false, true);
        // emit RewardClaimed(user1, expectedReward);
        
        // 部分取消质押
        stakingPool.unstake(unstakeAmount);
        
        vm.stopPrank();
        
        // 检查ETH返还
        assertEq(user1.balance, initialBalance + unstakeAmount);
        
        // 检查剩余质押
        (uint256 remainingAmount) = stakingPool.balanceOf(user1);
        assertEq(remainingAmount, stakeAmount - unstakeAmount);
        
        // 检查KK Token奖励
        assertEq(kkToken.balanceOf(user1), expectedReward);
        
        // 检查总质押量更新
        assertEq(stakingPool.totalStaked(), stakeAmount - unstakeAmount);
    }
    
    function testUnstakeAll() public {
        uint256 stakeAmount = 3 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟时间过去
        vm.roll(block.number + 10);
        
        uint256 initialBalance = user1.balance;
        
        // 全部取消质押
        stakingPool.unstakeAll();
        
        vm.stopPrank();
        
        // 检查ETH全部返还
        assertEq(user1.balance, initialBalance + stakeAmount);
        
        // 检查质押清零
        (uint256 amount) = stakingPool.balanceOf(user1);
        assertEq(amount, 0);
        
        // 检查总质押量更新
        assertEq(stakingPool.totalStaked(), 0);
    }
    
    function testUnstakeAllWithoutStaking() public {
        vm.startPrank(user1);
        
        // 没有质押就尝试全部取消质押
        vm.expectRevert("No staked amount");
        stakingPool.unstakeAll();
        
        vm.stopPrank();
    }
    
    function testUnstakeInsufficientAmount() public {
        uint256 stakeAmount = 1 ether;
        uint256 unstakeAmount = 2 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 尝试取消质押超过质押数量
        vm.expectRevert("Insufficient staked amount");
        stakingPool.unstake(unstakeAmount);
        
        vm.stopPrank();
    }
    
    function testUnstakeZeroAmount() public {
        uint256 stakeAmount = 1 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 尝试取消质押0数量
        vm.expectRevert("Cannot unstake 0 ETH");
        stakingPool.unstake(0);
        
        vm.stopPrank();
    }
    
    function testMultipleStakesByUser() public {
        uint256 stakeAmount1 = 1 ether;
        uint256 stakeAmount2 = 2 ether;
        
        vm.startPrank(user1);
        
        // 第一次质押
        stakingPool.stake{value: stakeAmount1}();
        
        // 模拟时间过去
        vm.roll(block.number + 5);
        
        // 第二次质押（应该先结算之前的奖励）
        uint256 expectedReward = 5 * REWARD_PER_BLOCK;
        
        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(user1, expectedReward);
        
        stakingPool.stake{value: stakeAmount2}();
        
        vm.stopPrank();
        
        // 检查总质押量
        (uint256 totalAmount) = stakingPool.balanceOf(user1);
        assertEq(totalAmount, stakeAmount1 + stakeAmount2);
        
        // 检查奖励已发放
        assertEq(kkToken.balanceOf(user1), expectedReward);
    }
    
    function testEmergencyWithdraw() public {
        uint256 stakeAmount = 2 ether;
        
        // 用户1质押
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟时间过去
        vm.roll(block.number + 10);
        
        uint256 initialBalance = user1.balance;
        
        // 紧急提取
        stakingPool.emergencyWithdraw();
        
        vm.stopPrank();
        
        // 检查ETH返还
        assertEq(user1.balance, initialBalance + stakeAmount);
        
        // 检查质押清零
        (uint256 amount) = stakingPool.balanceOf(user1);
        assertEq(amount, 0);
        
        // 检查没有奖励（紧急提取不给奖励）
        assertEq(kkToken.balanceOf(user1), 0);
        
        // 检查总质押量更新
        assertEq(stakingPool.totalStaked(), 0);
    }
    
    function testEmergencyWithdrawWithoutStaking() public {
        vm.startPrank(user1);
        
        // 没有质押就尝试紧急提取
        vm.expectRevert("No staked amount");
        stakingPool.emergencyWithdraw();
        
        vm.stopPrank();
    }
    
    function testUpdatePool() public {
        uint256 stakeAmount = 1 ether;
        
        // 用户质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        uint256 initialLastRewardBlock = stakingPool.lastRewardBlock();
        uint256 initialAccRewardPerShare = stakingPool.accRewardPerShare();
        
        // 模拟时间过去
        vm.roll(block.number + 5);
        
        // 手动更新池子
        stakingPool.updatePool();
        
        // 检查更新后的状态
        assertEq(stakingPool.lastRewardBlock(), block.number);
        assertGt(stakingPool.accRewardPerShare(), initialAccRewardPerShare);
    }
    
    function testRewardAccuracy() public {
        // 测试奖励计算的精确性
        uint256 stakeAmount1 = 1 ether;
        uint256 stakeAmount2 = 9 ether; // 1:9 比例
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount1}();
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: stakeAmount2}();
        
        // 挖矿100个区块
        vm.roll(block.number + 100);
        
        uint256 reward1 = stakingPool.earned(user1);
        uint256 reward2 = stakingPool.earned(user2);
        
        // 检查比例是否正确（1:9）
        assertApproxEqRel(reward1 * 9, reward2, 1e15); // 0.1% 误差范围
        
        // 检查总奖励
        uint256 totalExpectedReward = 100 * REWARD_PER_BLOCK;
        assertApproxEqAbs(reward1 + reward2, totalExpectedReward, 1e12); // 允许精度误差
    }
    
    function testLongTermStaking() public {
        uint256 stakeAmount = 1 ether;
        
        // 用户质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟长期质押（1000个区块）
        vm.roll(block.number + 1000);
        
        uint256 expectedReward = 1000 * REWARD_PER_BLOCK;
        uint256 actualReward = stakingPool.earned(user1);
        
        assertEq(actualReward, expectedReward);
        
        // 领取奖励
        vm.prank(user1);
        stakingPool.claim();
        
        assertEq(kkToken.balanceOf(user1), expectedReward);
    }
    
    function testKKTokenOnlyStakingPoolCanMint() public {
        uint256 mintAmount = 1000 * 1e18;
        
        // 尝试从非质押池地址铸造代币应该失败
        vm.expectRevert("Only staking pool can mint");
        kkToken.mint(user1, mintAmount);
        
        // 从质押池铸造应该成功（通过质押触发）
        vm.prank(user1);
        stakingPool.stake{value: 1 ether}();
        
        vm.roll(block.number + 10);
        
        vm.prank(user1);
        stakingPool.claim();
        
        // 验证代币已铸造
        assertGt(kkToken.balanceOf(user1), 0);
    }
    
    function testComplexScenario() public {
        // 复杂场景测试：多用户在不同时间质押和取消质押
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: 1 ether}();
        
        // 等待5个区块
        vm.roll(block.number + 5);
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: 2 ether}();
        
        // 等待10个区块
        vm.roll(block.number + 10);
        
        // 用户1部分取消质押
        vm.prank(user1);
        stakingPool.unstake(0.5 ether);
        
        // 等待5个区块
        vm.roll(block.number + 5);
        
        // 用户3质押
        vm.prank(user3);
        stakingPool.stake{value: 3 ether}();
        
        // 等待10个区块
        vm.roll(block.number + 10);
        
        // 检查所有用户都有奖励
        assertGt(kkToken.balanceOf(user1), 0); // 用户1已经通过unstake获得了奖励
        assertGt(stakingPool.earned(user2), 0);
        assertGt(stakingPool.earned(user3), 0);
        
        // 验证总质押量正确
        uint256 expectedTotalStaked = 0.5 ether + 2 ether + 3 ether; // 5.5 ether
        assertEq(stakingPool.totalStaked(), expectedTotalStaked);
    }
    
    function testFuzzStaking(uint256 stakeAmount) public {
        // 限制质押金额范围
        vm.assume(stakeAmount > 0 && stakeAmount <= 50 ether);
        vm.deal(user1, stakeAmount);
        
        // 执行质押
        vm.prank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 验证状态
        assertEq(stakingPool.totalStaked(), stakeAmount);
        (uint256 userAmount) = stakingPool.balanceOf(user1);
        assertEq(userAmount, stakeAmount);
    }
}
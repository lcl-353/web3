// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "../src/TestToken.sol";

contract VestingTest is Test {
    CustomVesting public vesting;
    TestToken public token;
    address public owner;
    address public beneficiary;

    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        beneficiary = makeAddr("beneficiary");
        
        // 部署合约
        vm.startPrank(owner);
        token = new TestToken();
        vesting = new CustomVesting(address(token), beneficiary);
        
        // 批准并转入代币
        token.approve(address(vesting), vesting.TOTAL_AMOUNT());
        vesting.fundVault();
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.released(), 0);
        assertEq(token.balanceOf(address(vesting)), vesting.TOTAL_AMOUNT());
    }

    function testNoReleaseDuringCliff() public {
        // 尝试在锁定期内释放代币
        vm.warp(vesting.startTime() + vesting.CLIFF() - 1 days);
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    function testReleaseAfterCliff() public {
        // 移动到锁定期结束后
        vm.warp(vesting.startTime() + vesting.CLIFF());
        
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
        
        // 验证释放的代币数量（应该是0，因为刚到cliff时间点）
        assertEq(vesting.released(), 0);
    }

    function testReleaseMiddleOfVesting() public {
        // 移动到vesting中间时间点
        uint256 midPoint = vesting.startTime() + vesting.CLIFF() + (vesting.DURATION() / 2);
        vm.warp(midPoint);
        
        vm.prank(beneficiary);
        vesting.release();
        
        // 验证释放了大约50%的代币
        assertApproxEqRel(
            vesting.released(),
            vesting.TOTAL_AMOUNT() / 2,
            0.01e18 // 允许1%的误差
        );
    }

    function testReleaseAfterVestingEnds() public {
        // 移动到vesting结束后
        vm.warp(vesting.startTime() + vesting.CLIFF() + vesting.DURATION());
        
        vm.prank(beneficiary);
        vesting.release();
        
        // 验证所有代币都被释放
        assertEq(vesting.released(), vesting.TOTAL_AMOUNT());
        assertEq(token.balanceOf(beneficiary), vesting.TOTAL_AMOUNT());
    }

    function testMultipleReleases() public {
        // 第一次释放 - 在中间时间点
        uint256 midPoint = vesting.startTime() + vesting.CLIFF() + (vesting.DURATION() / 2);
        vm.warp(midPoint);
        vm.prank(beneficiary);
        vesting.release();
        uint256 firstRelease = vesting.released();

        // 第二次释放 - 在结束时间点
        vm.warp(vesting.startTime() + vesting.CLIFF() + vesting.DURATION());
        vm.prank(beneficiary);
        vesting.release();
        uint256 secondRelease = vesting.released() - firstRelease;

        // 验证总释放量等于TOTAL_AMOUNT
        assertEq(vesting.released(), vesting.TOTAL_AMOUNT());
        assertEq(token.balanceOf(beneficiary), vesting.TOTAL_AMOUNT());
    }
}

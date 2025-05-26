// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomVesting is Ownable {
    IERC20 public immutable token;
    address public beneficiary;
    uint256 public startTime;
    uint256 public constant CLIFF = 365 days; // 12个月
    uint256 public constant DURATION = 730 days; // 24个月
    uint256 public constant TOTAL_AMOUNT = 1_000_000e18; // 100万代币（假设18位精度）
    uint256 public released;

    event TokensReleased(uint256 amount);
    
    constructor(address _token, address _beneficiary) Ownable(msg.sender) {
        token = IERC20(_token);
        beneficiary = _beneficiary;
        startTime = block.timestamp; // 部署时间即开始计时
    }
    
    // 转入代币（需在部署后调用）
    function fundVault() external onlyOwner {
        token.transferFrom(msg.sender, address(this), TOTAL_AMOUNT);
    }
    
    // 释放可领取代币
    function release() external {
        uint256 releasable = vestedAmount(block.timestamp) - released;
        require(releasable > 0, "No tokens to release");
        
        released += releasable;
        token.transfer(beneficiary, releasable);
        emit TokensReleased(releasable);
    }
    
    // 计算已vesting额度
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < startTime + CLIFF) {
            return 0;
        } else if (timestamp >= startTime + CLIFF + DURATION) {
            return TOTAL_AMOUNT;
        } else {
            uint256 elapsed = timestamp - (startTime + CLIFF);
            return (TOTAL_AMOUNT * elapsed) / DURATION;
        }
    }
}
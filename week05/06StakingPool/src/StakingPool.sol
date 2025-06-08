// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KKToken - 质押奖励代币
 * @dev ERC20代币，用作质押奖励
 */
contract KKToken is ERC20, Ownable {
    address public stakingPool;
    
    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {}
    
    /**
     * @dev 设置质押池地址，只有质押池可以铸造代币
     * @param _stakingPool 质押池合约地址
     */
    function setStakingPool(address _stakingPool) external onlyOwner {
        stakingPool = _stakingPool;
    }
    
    /**
     * @dev 铸造代币，只有质押池可以调用
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == stakingPool, "Only staking pool can mint");
        _mint(to, amount);
    }
}

/**
 * @title StakingPool - ETH质押池合约
 * @dev 用户可以质押ETH获得KK Token奖励
 */
contract StakingPool is ReentrancyGuard {
    KKToken public immutable kkToken;
    
    // 每个区块产出的KK Token数量 (10 * 10^18)
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    // 质押信息结构体
    struct StakeInfo {
        uint256 amount;           // 质押数量
        uint256 rewardDebt;       // 已计算的奖励债务
    }
    
    // 用户质押信息映射
    mapping(address => StakeInfo) public stakes;
    
    // 全局状态变量
    uint256 public totalStaked;                    // 总质押量
    uint256 public accRewardPerShare;              // 累积每份奖励
    uint256 public lastRewardBlock;                // 最后更新奖励的区块号
    
    // 精度因子，用于避免小数计算
    uint256 private constant ACC_PRECISION = 1e12;
    
    // 事件定义
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    /**
     * @dev 构造函数
     * @param _kkToken KK Token合约地址
     */
    constructor(address _kkToken) {
        kkToken = KKToken(_kkToken);
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev 更新奖励累积值
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        // 计算需要分发的奖励
        uint256 blocksSinceLastReward = block.number - lastRewardBlock;
        uint256 totalReward = blocksSinceLastReward * REWARD_PER_BLOCK;
        
        // 更新累积每份奖励
        accRewardPerShare += (totalReward * ACC_PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev 计算用户待领取奖励
     * @param user 用户地址
     * @return 待领取奖励数量
     */
    function earned(address user) external view returns (uint256) {
        StakeInfo storage userStake = stakes[user];
        
        if (userStake.amount == 0) {
            return 0;
        }
        
        uint256 tempAccRewardPerShare = accRewardPerShare;
        
        // 如果需要更新累积奖励
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocksSinceLastReward = block.number - lastRewardBlock;
            uint256 totalReward = blocksSinceLastReward * REWARD_PER_BLOCK;
            tempAccRewardPerShare += (totalReward * ACC_PRECISION) / totalStaked;
        }
        
        return (userStake.amount * tempAccRewardPerShare) / ACC_PRECISION - userStake.rewardDebt;
    }
    
    /**
     * @dev 质押ETH
     */
    function stake() external payable nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        updatePool();
        
        StakeInfo storage userStake = stakes[msg.sender];
        
        // 如果用户已有质押，先结算之前的奖励
        if (userStake.amount > 0) {
            uint256 pending = (userStake.amount * accRewardPerShare) / ACC_PRECISION - userStake.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }
        
        // 更新用户质押信息
        userStake.amount += msg.value;
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / ACC_PRECISION;
        
        // 更新总质押量
        totalStaked += msg.value;
        
        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev 取消所有质押
     */
    function unstakeAll() external {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No staked amount");
        
        uint256 amount = userStake.amount;
        unstake(amount);
    }
    
    /**
     * @dev 取消质押指定数量的ETH
     * @param amount 要取消质押的ETH数量
     */
    function unstake(uint256 amount) public nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Cannot unstake 0 ETH");
        
        updatePool();
        
        // 计算并发放奖励
        uint256 pending = (userStake.amount * accRewardPerShare) / ACC_PRECISION - userStake.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }
        
        // 更新用户质押信息
        userStake.amount -= amount;
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / ACC_PRECISION;
        
        // 更新总质押量
        totalStaked -= amount;
        
        // 转回ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取奖励而不取消质押
     */
    function claim() external nonReentrant {
        updatePool();
        
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No staked amount");
        
        uint256 pending = (userStake.amount * accRewardPerShare) / ACC_PRECISION - userStake.rewardDebt;
        require(pending > 0, "No pending reward");
        
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / ACC_PRECISION;
        
        kkToken.mint(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }
    
    /**
     * @dev 获取用户质押信息
     * @param user 用户地址
     * @return amount 质押数量
     */
    function balanceOf(address user) external view returns (uint256 amount) {
        StakeInfo storage userStake = stakes[user];
        amount = userStake.amount;
    }

    /**
     * @dev 紧急取回函数，仅供合约所有者使用
     */
    function emergencyWithdraw() external {
        StakeInfo storage userStake = stakes[msg.sender];
        uint256 amount = userStake.amount;
        require(amount > 0, "No staked amount");
        
        // 清空用户质押信息（不给奖励）
        userStake.amount = 0;
        userStake.rewardDebt = 0;
        
        totalStaked -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
}
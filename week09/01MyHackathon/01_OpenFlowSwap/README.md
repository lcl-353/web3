# SushiSwap Clone - DeFi Project with DAO Governance

这是一个仿照SushiSwap的完整DeFi项目，实现了去中心化交易所(DEX)、流动性挖矿和**DAO治理**功能。

## 项目特点

### 1. DEX功能
- **流动性添加与移除**: 用户可以向交易对提供流动性并获得LP代币
- **Token交换**: 支持任意ERC20代币之间的交换
- **自动做市商(AMM)**: 基于恒定乘积公式(x*y=k)的价格发现机制
- **手续费机制**: 每次交易收取0.3%的手续费，分配给流动性提供者

### 2. 流动性挖矿
- **SUSHI代币奖励**: 为LP代币质押者提供SUSHI代币奖励
- **多池支持**: 支持多个交易对同时进行流动性挖矿
- **灵活的奖励分配**: 管理员可以调整不同池子的奖励分配比例

### 3. DAO治理 🆕
- **去中心化治理**: SUSHI代币持有者可参与协议治理
- **提案系统**: 创建、投票、执行治理提案
- **时间锁保护**: 2天执行延迟确保安全性
- **法定人数**: 4%参与度要求防止小群体操控
- **投票权委托**: 支持投票权委托机制

## 合约架构

```
src/
├── dex/                    # DEX核心合约
│   ├── SushiFactory.sol    # 工厂合约，管理交易对
│   ├── SushiPair.sol       # 交易对合约，实现AMM逻辑
│   ├── SushiRouter.sol     # 路由合约，提供用户友好接口
│   └── SushiERC20.sol      # LP代币合约
├── farming/                # 流动性挖矿合约
│   ├── SushiToken.sol      # SUSHI治理代币 (支持ERC20Votes)
│   └── MasterChef.sol      # 挖矿主合约
├── governance/             # DAO治理合约 🆕
│   └── SimpleDAO.sol       # 完整的DAO治理实现
├── interfaces/             # 接口定义
│   └── ISushiGovernor.sol  # 治理接口
├── libraries/              # 工具库
└── mocks/                  # 测试用合约
```

## 主要功能

### DEX功能

#### 1. 添加流动性
```solidity
// 通过Router合约添加流动性
router.addLiquidity(
    tokenA,           // 代币A地址
    tokenB,           // 代币B地址
    amountADesired,   // 期望添加的代币A数量
    amountBDesired,   // 期望添加的代币B数量
    amountAMin,       // 最小代币A数量
    amountBMin,       // 最小代币B数量
    to,               // LP代币接收地址
    deadline          // 截止时间
);
```

#### 2. 移除流动性
```solidity
// 移除流动性
router.removeLiquidity(
    tokenA,           // 代币A地址
    tokenB,           // 代币B地址
    liquidity,        // 要移除的LP代币数量
    amountAMin,       // 最小获得的代币A数量
    amountBMin,       // 最小获得的代币B数量
    to,               // 代币接收地址
    deadline          // 截止时间
);
```

#### 3. 代币交换
```solidity
// 精确输入交换
router.swapExactTokensForTokens(
    amountIn,         // 输入代币数量
    amountOutMin,     // 最小输出数量
    path,             // 交换路径
    to,               // 输出代币接收地址
    deadline          // 截止时间
);
```

### 流动性挖矿

#### 1. 质押LP代币
```solidity
// 质押LP代币到MasterChef
masterChef.deposit(pid, amount);
```

#### 2. 取消质押并领取奖励
```solidity
// 取消质押LP代币并领取SUSHI奖励
masterChef.withdraw(pid, amount);
```

#### 3. 查看待领取奖励
```solidity
// 查看用户待领取的SUSHI奖励
uint256 pending = masterChef.pendingSushi(pid, user);
```

### DAO治理 🆕

#### 1. 获取投票权
```solidity
// 委托投票权给自己
sushiToken.delegate(msg.sender);

// 查看投票权
uint256 votes = sushiToken.getVotes(account);
```

#### 2. 创建提案
```solidity
// 创建治理提案
uint256 proposalId = dao.propose(
    target,           // 目标合约地址
    value,            // ETH数量
    data,             // 调用数据
    description       // 提案描述
);
```

#### 3. 投票
```solidity
// 对提案投票: 0=反对, 1=支持, 2=弃权
dao.castVote(proposalId, 1);
```

#### 4. 执行提案
```solidity
// 队列提案
dao.queue(proposalId);

// 执行提案 (等待时间锁延迟后)
dao.execute(proposalId);
```

## 治理参数

| 参数 | 值 | 描述 |
|------|-----|------|
| 投票延迟 | 1天 | 提案创建后到投票开始的延迟 |
| 投票期间 | 1周 | 投票持续时间 |
| 执行延迟 | 2天 | 投票成功后到执行的延迟 |
| 提案门槛 | 1000 SUSHI | 创建提案需要的最少代币数量 |
| 法定人数 | 4% | 投票有效需要的最少参与度 |

## 部署步骤

1. **环境配置**
```bash
# 复制环境变量文件
cp .env.example .env

# 编辑.env文件，设置私钥
PRIVATE_KEY=your_private_key_here
```

2. **编译合约**
```bash
forge build --via-ir
```

3. **部署合约**
```bash
# 部署完整的DAO治理系统
forge script script/DeploySimpleDAO.s.sol --rpc-url <RPC_URL> --broadcast
```

## 使用示例

### 1. 创建交易对
```javascript
// 通过Factory创建新的交易对
const pairAddress = await factory.createPair(tokenA.address, tokenB.address);
```

### 2. 添加流动性挖矿池
```javascript
// 管理员添加新的挖矿池
await masterChef.add(
    100,              // 分配点数
    pairAddress,      // LP代币地址
    false             // 是否立即更新所有池子
);
```

### 3. DAO治理流程 🆕
```javascript
// 1. 委托投票权
await sushiToken.delegate(userAddress);

// 2. 创建提案
const proposalId = await dao.propose(
    masterChef.address,
    0,
    masterChef.interface.encodeFunctionData("updateSushiPerBlock", [ethers.utils.parseEther("2")]),
    "Increase SUSHI emission to 2 tokens per block"
);

// 3. 投票
await dao.castVote(proposalId, 1); // 支持

// 4. 执行提案
await dao.queue(proposalId);
// 等待时间锁延迟...
await dao.execute(proposalId);
```

### 4. 用户交互流程
```javascript
// 1. 用户批准代币
await tokenA.approve(router.address, amount);
await tokenB.approve(router.address, amount);

// 2. 添加流动性
await router.addLiquidity(
    tokenA.address,
    tokenB.address,
    amountA,
    amountB,
    0,
    0,
    user.address,
    deadline
);

// 3. 质押LP代币进行挖矿
const lpToken = await factory.getPair(tokenA.address, tokenB.address);
await lpToken.approve(masterChef.address, lpAmount);
await masterChef.deposit(0, lpAmount);
```

## 安全特性

1. **重入攻击保护**: 所有关键函数都使用了ReentrancyGuard
2. **权限控制**: 关键管理功能只能由合约所有者调用
3. **溢出保护**: 使用SafeMath库防止整数溢出
4. **滑点保护**: 用户可以设置最小输出数量防止滑点过大
5. **治理安全**: 时间锁延迟、法定人数要求、投票权委托 🆕

## 测试

```bash
# 运行所有测试
forge test --via-ir

# 运行DAO治理测试
forge test --match-contract SimpleDAOTest --via-ir

# 运行特定测试
forge test --match-test testAddLiquidity --via-ir

# 查看测试覆盖率
forge coverage
```

## 测试结果

### 整体测试覆盖
- **SimpleDAO测试**: 16/16 通过 (100% ✅)
- **功能测试**: 覆盖所有核心合约函数
- **集成测试**: 完整的DeFi+DAO流程测试

### 关键功能验证
✅ DEX交易和流动性管理  
✅ 流动性挖矿和奖励分发  
✅ DAO治理提案和投票  
✅ 时间锁安全机制  
✅ 权限控制和访问管理  

## 技术规格

- **Solidity版本**: ^0.8.19
- **开发框架**: Foundry
- **依赖库**: OpenZeppelin Contracts
- **编译优化**: Yul IR编译器 (--via-ir)
- **网络兼容**: 所有EVM兼容链

## 文档

### 详细文档
- **[DAO治理指南](DAO_GOVERNANCE_GUIDE.md)**: 完整的DAO使用指南
- **[项目总结](PROJECT_SUMMARY.md)**: 技术规格和功能概述
- **[测试报告](TEST_COVERAGE_REPORT.md)**: 详细的测试覆盖报告

### 治理示例
查看 `DAO_GOVERNANCE_GUIDE.md` 了解如何：
- 创建和管理治理提案
- 参与投票和委托
- 执行协议升级
- 管理资金和参数

## 注意事项

1. 本项目仅用于学习和测试目的
2. 在主网使用前请进行充分的安全审计
3. 初始化代码哈希需要根据实际部署的合约字节码计算
4. 建议在测试网先进行充分测试
5. DAO治理需要社区积极参与才能有效运行 🆕

## 许可证

MIT License

# DeFi协议部署指南

本指南将帮助您在Foundry本地网络上部署完整的DeFi协议栈。

## 🚀 快速开始

### 1. 启动Foundry本地网络

```bash
# 启动anvil本地网络
anvil
```

这将启动一个本地区块链，默认监听 `http://localhost:8545`

### 2. 部署协议

```bash
# 编译合约
forge build --via-ir

# 部署所有合约到本地网络
forge script script/DeployToFoundry.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 📋 部署内容

部署脚本将创建以下合约和设置：

### 核心合约
- **SushiFactory**: DEX工厂合约，管理交易对创建
- **SushiRouter**: 路由合约，提供用户友好的交易接口
- **SushiToken**: SUSHI治理代币
- **MasterChef**: 流动性挖矿主合约
- **SimpleDAO**: DAO治理合约

### 测试代币
- **TokenA (TKA)**: 测试代币A
- **TokenB (TKB)**: 测试代币B  
- **WETH**: 包装ETH代币
- **USDC**: 稳定币代币

### 交易对
- TKA/TKB
- TKA/WETH
- TKB/WETH
- USDC/WETH

### 流动性挖矿池
- 池子0: TKA/TKB (100 allocation points)
- 池子1: TKA/WETH (200 allocation points)
- 池子2: TKB/WETH (150 allocation points)
- 池子3: USDC/WETH (300 allocation points)

## 💡 使用示例

### 添加流动性

```solidity
// 1. 授权Router花费代币
tokenA.approve(routerAddress, amount);
tokenB.approve(routerAddress, amount);

// 2. 添加流动性
router.addLiquidity(
    tokenA,
    tokenB,
    amountADesired,
    amountBDesired,
    amountAMin,
    amountBMin,
    to,
    deadline
);
```

### 开始流动性挖矿

```solidity
// 1. 授权MasterChef花费LP代币
lpToken.approve(masterChefAddress, lpAmount);

// 2. 质押LP代币开始挖矿
masterChef.deposit(poolId, lpAmount);
```

### Token交换

```solidity
// 1. 授权Router
tokenA.approve(routerAddress, swapAmount);

// 2. 执行交换
address[] memory path = new address[](2);
path[0] = tokenA;
path[1] = tokenB;

router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline
);
```

### DAO治理

```solidity
// 1. 创建提案
uint256 proposalId = dao.propose(
    target,
    value,
    data,
    description
);

// 2. 投票
dao.castVote(proposalId, 1); // 1 = 支持

// 3. 排队执行
dao.queue(proposalId);

// 4. 执行提案
dao.execute(proposalId);
```

## 🔧 环境变量配置

创建 `.env` 文件（可选）：

```env
# 私钥（默认使用anvil的第一个账户）
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 开发者地址
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# 国库地址
TREASURY_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

## 📊 部署后验证

部署完成后，检查以下内容：

```bash
# 检查合约是否正确部署
cast call <FACTORY_ADDRESS> "allPairsLength()" --rpc-url http://localhost:8545

# 检查SUSHI每块奖励
cast call <MASTERCHEF_ADDRESS> "sushiPerBlock()" --rpc-url http://localhost:8545

# 检查池子数量
cast call <MASTERCHEF_ADDRESS> "poolLength()" --rpc-url http://localhost:8545
```

## 🎮 交互演示

使用交互脚本演示完整流程：

```bash
# 注意：需要先更新InteractWithContracts.s.sol中的合约地址
forge script script/InteractWithContracts.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 🧪 运行测试

验证部署的合约功能：

```bash
# 运行完整DeFi流程测试
forge test --match-contract SimplifiedDeFiFlowTest --via-ir -v

# 运行特定测试
forge test --match-test testCompleteDeFiFlow --via-ir -vvv
```

## 📁 文件结构

```
script/
├── DeployToFoundry.s.sol      # 主部署脚本
├── InteractWithContracts.s.sol # 交互演示脚本
└── README.md                   # 本文档

src/
├── dex/                       # DEX相关合约
├── farming/                   # 流动性挖矿合约
├── governance/                # DAO治理合约
├── interfaces/                # 接口定义
├── libraries/                 # 工具库
└── mocks/                     # 测试用合约
```

## ⚠️ 注意事项

1. **网络环境**: 本脚本专为Foundry本地网络设计
2. **私钥安全**: 生产环境中请使用安全的私钥管理方式
3. **权限管理**: 部署后建议将关键合约的所有权转移给DAO
4. **代币供应**: 测试代币拥有无限铸造权限，请勿用于生产环境

## 🛠️ 故障排除

### 编译错误 "Stack too deep"
```bash
# 使用via-ir编译选项
forge build --via-ir
```

### RPC连接错误
```bash
# 确保anvil正在运行
anvil

# 检查RPC URL是否正确
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545
```

### Gas费用不足
```bash
# anvil默认提供充足的测试ETH，如需要可以指定更多
anvil --balance 10000
```

## 🎯 下一步

部署成功后，您可以：

1. 🏊‍♂️ **提供流动性**: 向交易对添加流动性获得LP代币
2. ⛏️ **开始挖矿**: 质押LP代币获得SUSHI奖励
3. 🔄 **交换代币**: 使用DEX进行代币交换
4. 🗳️ **参与治理**: 使用SUSHI代币参与DAO投票
5. 🔧 **自定义配置**: 通过DAO提案调整协议参数

## 📞 支持

如需帮助，请查看：
- Foundry文档: https://book.getfoundry.sh/
- 测试用例: `test/SimplifiedDeFiFlowTest.t.sol`
- 合约源码: `src/` 目录

祝您部署顺利！🎉

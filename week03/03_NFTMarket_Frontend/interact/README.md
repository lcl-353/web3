# NFT Market 交互指南

这个交互脚本提供了与 NFT 市场合约交互的完整功能，包括 NFT 的铸造、上架、购买等操作。

## 准备工作

1. 安装依赖：
```bash
cd interact
npm install
```

2. 设置环境变量：
```bash
# Linux/macOS
# 注意：必须使用部署合约时的私钥，因为只有合约 owner 才能铸造 NFT
export PRIVATE_KEY=your_private_key_here  # 不需要 0x 前缀

# Windows PowerShell
$env:PRIVATE_KEY="your_private_key_here"  # 不需要 0x 前缀
```

3. 确认合约所有者：
   - NFT 合约在部署时将 `msg.sender` 设置为 owner
   - 只有 owner 可以调用 `safeMint` 函数铸造 NFT
   - 如果你不是合约 owner，需要使用部署合约时的账户私钥

3. 确保本地 Foundry 节点正在运行：
```bash
anvil
```

## 可用命令

### 1. 铸造 NFT
铸造一个新的 NFT 到指定地址：
```bash
node interact.js mint 0xYourAddress
```

### 2. 查询 NFT 所有者
查询指定 tokenId 的 NFT 所有者：
```bash
node interact.js owner 1  # 1 是 tokenId
```

### 3. 上架 NFT
将 NFT 上架到市场（价格单位为 wei）：
```bash
node interact.js list 1 1000000000000000000  # 上架 tokenId 1，价格为 1 个代币
```

### 4. 查询上架信息
查询某个 NFT 的上架信息：
```bash
node interact.js get-listing 1  # 1 是 tokenId
```

### 5. 购买 NFT（回调方式）
使用 transferWithCallback 方式购买 NFT：
```bash
node interact.js buy-callback 1 1000000000000000000  # 购买 tokenId 1，价格为 1 个代币
```

### 6. 购买 NFT（传统方式）
使用传统的 approve + transferFrom 方式购买 NFT：
```bash
node interact.js buy-traditional 1  # 购买 tokenId 1
```

### 7. 查询 ERC20 余额
查询指定地址的 ERC20 代币余额：
```bash
node interact.js balance 0xYourAddress
```

## 交互流程示例

1. 完整的 NFT 交易流程：
```bash
# 1. 铸造 NFT
node interact.js mint 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# 2. 确认 NFT 所有权
node interact.js owner 0

# 3. 上架 NFT（价格为 1 个代币）
node interact.js list 0 1000000000000000000

# 4. 确认上架信息
node interact.js get-listing 1

# 5. 查看买家 ERC20 余额
node interact.js balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

# 6. 购买 NFT（使用回调方式）
node interact.js buy-callback 1 1000000000000000000

# 7. 确认新的所有者
node interact.js owner 1
```

## 错误处理

1. 如果遇到 "invalid private key" 错误，确保：
   - PRIVATE_KEY 环境变量已正确设置
   - 私钥格式正确（64 个字符的十六进制字符串，不需要 0x 前缀）

2. 如果遇到 "contract not found" 错误，确保：
   - Foundry 节点正在运行
   - deployedAddresses.json 中的合约地址正确

3. 如果遇到 "insufficient funds" 错误：
   - 确保账户有足够的 ETH 支付 gas
   - 购买 NFT 时确保有足够的 ERC20 代币余额

## 注意事项

1. 所有金额都使用 wei 为单位（18位小数）
2. TokenId 从 0 开始递增
3. 在执行购买操作前，确保已有足够的 ERC20 代币
4. 上架 NFT 时会自动处理 NFT 的授权
5. 购买 NFT 时会自动处理 ERC20 代币的授权

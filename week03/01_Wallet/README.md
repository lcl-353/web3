# CLI Wallet

一个基于 Viem.js 的命令行钱包工具，支持以下功能：

- 生成私钥
- 查询 ETH 余额
- 查询 ERC20 代币余额
- 发送 ERC20 代币转账交易

## 安装

```bash
npm install
```

## 配置

1. 复制 `.env` 文件并填写配置：
```bash
cp .env.example .env
```

2. 在 `.env` 文件中填写：
- `SEPOLIA_RPC_URL`：Sepolia 测试网的 RPC URL
- `ERC20_CONTRACT_ADDRESS`：ERC20 代币合约地址

## 使用方法

### 生成新钱包
```bash
npm run wallet generate
```

### 查询 ETH 余额
```bash
npm run wallet balance <address>
```

### 查询代币余额
```bash
npm run wallet token-balance <address>
```

### 发送代币
```bash
npm run wallet send-token <to_address> <amount>
```

## 注意事项

1. 钱包信息会保存在 `wallet.json` 文件中，请妥善保管
2. 使用 Sepolia 测试网，请确保有足够的测试网 ETH
3. 发送交易前请确保有足够的 ERC20 代币

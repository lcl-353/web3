# NFT市场前端应用

这是一个使用 Next.js + Wagmi + Viem 构建的NFT市场前端应用，可以与NFTMarket智能合约进行交互。

## 功能特性

- 🔗 **钱包连接**: 支持MetaMask、WalletConnect等多种钱包连接方式
- 📦 **NFT上架**: 用户可以上架自己的NFT到市场（自动检查并提示授权）
- 🛒 **NFT购买**: 用户可以直接购买市场上的NFT（自动检查并提示代币授权）
- ✍️ **Permit购买**: 支持通过签名进行无gas费用的NFT购买
- 📋 **NFT列表**: 显示市场上所有可购买的NFT
- 👤 **用户NFT管理**: 查看和管理用户拥有的NFT
- ✅ **智能授权**: 自动检查NFT和代币授权状态，引导用户完成授权操作

## 技术栈

- **前端框架**: Next.js 15 (App Router)
- **区块链交互**: Wagmi v2 + Viem
- **样式**: Tailwind CSS
- **类型安全**: TypeScript
- **状态管理**: React Hooks

## 项目结构

```
src/
├── app/                    # Next.js App Router
│   └── page.tsx           # 主页面
├── components/            # React组件
│   ├── providers/         # Provider组件
│   │   └── WagmiProvider.tsx
│   ├── ui/               # UI组件
│   │   └── Button.tsx
│   ├── NFTMarket.tsx     # 主市场组件
│   ├── NFTList.tsx       # NFT列表组件
│   ├── UserNFTs.tsx      # 用户NFT组件
│   ├── WalletConnect.tsx # 钱包连接组件
│   └── ApproveModal.tsx  # 授权模态框组件
├── config/               # 配置文件
│   ├── contracts.ts      # 合约配置
│   └── wagmi.ts          # Wagmi配置
├── lib/                  # 工具函数
│   └── utils.ts
├── types/                # TypeScript类型定义
│   └── index.ts
└── abi/                  # 合约ABI文件
    ├── NFTMarket.json
    ├── ERC721.json
    └── ERC20.json
```

## 安装和运行

1. 安装依赖:
```bash
npm install
```

2. 配置合约地址:
编辑 `src/config/contracts.ts` 文件，填入实际部署的合约地址:
```typescript
export const CONTRACT_ADDRESSES = {
  NFT_MARKET: '0x...', // NFTMarket合约地址
  NFT_COLLECTION: '0x...', // NFT合约地址
  PAYMENT_TOKEN: '0x...', // 支付代币地址
}
```

3. 配置WalletConnect (可选):
编辑 `src/config/wagmi.ts` 文件，填入WalletConnect的Project ID:
```typescript
walletConnect({
  projectId: 'YOUR_WALLET_CONNECT_PROJECT_ID',
})
```

4. 启动开发服务器:
```bash
npm run dev
```

5. 打开浏览器访问 [http://localhost:3000](http://localhost:3000)

## 合约交互功能

### 1. 上架NFT (list)
- 用户可以将自己的NFT上架到市场
- **自动检查NFT授权状态**，如果未授权会弹出授权模态框
- 需要指定NFT合约地址、Token ID、价格和支付代币
- 授权成功后自动继续上架操作

### 2. 购买NFT (purchase)
- 用户可以直接购买市场上的NFT
- **自动检查代币授权状态**，如果未授权会弹出授权模态框
- 需要支付相应的代币
- 授权成功后自动继续购买操作

### 3. Permit购买 (permitBuy)
- 支持通过签名进行无gas费用的NFT购买
- 需要提供有效的签名
- 无需预先授权代币

### 4. NFT列表
- 显示市场上所有可购买的NFT
- 包含价格、卖家等信息
- 购买时自动检查代币授权

### 5. 智能授权系统
- **ApproveModal组件**: 统一的授权界面
- **NFT授权**: 检查 `getApproved()` 函数，确保NFT已授权给市场合约
- **代币授权**: 检查 `allowance()` 函数，确保代币授权额度足够
- **自动引导**: 检测到未授权时自动弹出授权模态框
- **状态提示**: 实时显示授权状态

## 授权流程

### NFT上架授权流程
1. 用户填写上架表单
2. 系统检查NFT是否已授权给市场合约
3. 如果未授权，弹出授权模态框
4. 用户确认授权，调用NFT合约的 `approve()` 函数
5. 授权成功后自动继续上架操作

### 代币购买授权流程
1. 用户点击购买NFT
2. 系统检查代币授权额度是否足够
3. 如果授权不足，弹出授权模态框
4. 用户确认授权，调用代币合约的 `approve()` 函数
5. 授权成功后自动继续购买操作

## 环境要求

- Node.js 18+
- 支持的网络: Ethereum Mainnet, Sepolia, Localhost

## 注意事项

1. **合约地址配置**: 使用前请确保在 `src/config/contracts.ts` 中配置了正确的合约地址
2. **网络支持**: 确保钱包连接到正确的网络
3. **Gas费用**: 除了Permit购买外，其他操作都需要支付gas费用
4. **NFT授权**: 上架NFT前需要先授权NFTMarket合约操作你的NFT
5. **代币授权**: 购买NFT前需要先授权足够的代币给市场合约
6. **授权额度**: 代币授权建议设置足够大的额度，避免频繁授权

## 开发说明

- 项目使用TypeScript确保类型安全
- 使用Wagmi v2的最新API进行区块链交互
- 组件采用函数式组件和React Hooks
- 样式使用Tailwind CSS实现响应式设计
- 授权逻辑封装在独立的ApproveModal组件中，便于复用

## 许可证

MIT License

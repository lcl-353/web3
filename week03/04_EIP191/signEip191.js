import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { mainnet } from 'viem/chains';

// 1. 手动输入私钥
const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // 替换为你的私钥

// 2. 从私钥生成账户
const account = privateKeyToAccount(privateKey);

// 3. 创建钱包客户端（无需连接MetaMask）
const client = createWalletClient({
  account,
  chain: mainnet,
  transport: http(), // 使用HTTP Provider
});

// 4. 签名消息
const signature = await client.signMessage({
  account,
  message: "hello world",
});
console.log("签名结果:", signature);
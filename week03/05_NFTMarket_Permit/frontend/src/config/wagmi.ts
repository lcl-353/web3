import { http, createConfig } from 'wagmi'
import { foundry } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

// 配置支持的链 - 仅支持 foundry 本地网络
const chains = [foundry] as const

// 创建Wagmi配置
export const config = createConfig({
  chains,
  connectors: [
    injected(), // 这个会自动检测已安装的钱包（包括MetaMask）
  ],
  transports: {
    [foundry.id]: http('http://127.0.0.1:8545'),
  },
}) 
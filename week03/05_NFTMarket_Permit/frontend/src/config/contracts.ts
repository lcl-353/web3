import NFTMarketABI from '../abi/NFTMarket.json'
import ERC721ABI from '../abi/ERC721.json'
import ERC20ABI from '../abi/ERC20.json'

// 合约地址配置 - 需要根据实际部署的地址进行修改
export const CONTRACT_ADDRESSES = {
  // 示例地址，需要替换为实际部署的地址
  NFT_MARKET: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0', // NFTMarket合约地址
  NFT_COLLECTION: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // NFT合约地址
  PAYMENT_TOKEN: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // 支付代币地址 (如USDC, WETH等)
} as const

// 合约ABI配置
export const CONTRACT_ABIS = {
  NFT_MARKET: NFTMarketABI,
  ERC721: ERC721ABI,
  ERC20: ERC20ABI,
} as const

// 链ID配置
export const SUPPORTED_CHAINS = {
  MAINNET: 1,
  SEPOLIA: 11155111,
  LOCALHOST: 31337,
} as const

// 默认链配置
export const DEFAULT_CHAIN_ID = SUPPORTED_CHAINS.LOCALHOST 
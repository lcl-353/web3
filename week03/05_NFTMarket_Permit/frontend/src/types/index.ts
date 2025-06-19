// NFT列表项类型
export interface NFTListing {
  seller: string
  nftContract: string
  tokenId: bigint
  price: bigint
  paymentToken: string
  isActive: boolean
}

// Mint结构类型 (用于permitBuy)
export interface Mint {
  to: string
  tokenId: bigint
}

// 上架NFT的参数类型
export interface ListNFTParams {
  nftContract: string
  tokenId: bigint
  price: bigint
  paymentToken: string
}

// 购买NFT的参数类型
export interface BuyNFTParams {
  nftContract: string
  tokenId: bigint
}

// Permit购买NFT的参数类型
export interface PermitBuyParams {
  nftContract: string
  tokenId: bigint
  mint: Mint
  signature: string
}

// 用户NFT类型
export interface UserNFT {
  tokenId: bigint
  nftContract: string
  owner: string
  approved: string
} 
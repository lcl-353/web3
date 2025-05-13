#!/usr/bin/env node
import { createPublicClient, createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { foundry } from 'viem/chains'
import { readFileSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// Load contract addresses
const addresses = JSON.parse(
  readFileSync(join(__dirname, 'deployedAddresses.json'), 'utf8')
)

// Load ABIs
const nftAbi = JSON.parse(
  readFileSync(join(__dirname, './abi/MyNFT.json'), 'utf8')
)
const erc20Abi = JSON.parse(
  readFileSync(join(__dirname, './abi/MyERC20.json'), 'utf8')
)
const marketAbi = JSON.parse(
  readFileSync(join(__dirname, './abi/MyNFTMarket.json'), 'utf8')
)

// Setup wallet and client
const privateKey = process.env.PRIVATE_KEY
if (!privateKey) {
  throw new Error('PRIVATE_KEY environment variable is required')
}

const account = privateKeyToAccount(privateKey)

const publicClient = createPublicClient({
  chain: foundry,
  transport: http('http://localhost:8545')
})

const walletClient = createWalletClient({
  account,
  chain: foundry,
  transport: http('http://localhost:8545')
})

// Contract interaction functions
async function mintNFT(to) {
  const { request } = await publicClient.simulateContract({
    address: addresses.MyNFT,
    abi: nftAbi,
    functionName: 'safeMint',
    args: [to],
    account
  })
  const hash = await walletClient.writeContract(request)
  return hash
}

async function approveERC20(spender, amount) {
  const { request } = await publicClient.simulateContract({
    address: addresses.BaseERC20,
    abi: erc20Abi,
    functionName: 'approve',
    args: [spender, amount],
    account
  })
  const hash = await walletClient.writeContract(request)
  return hash
}

async function listNFT(tokenId, price) {
  // First approve NFT
  const { request: approveRequest } = await publicClient.simulateContract({
    address: addresses.MyNFT,
    abi: nftAbi,
    functionName: 'approve',
    args: [addresses.NFTMarket, tokenId],
    account
  })
  await walletClient.writeContract(approveRequest)

  // Then list NFT
  const { request } = await publicClient.simulateContract({
    address: addresses.NFTMarket,
    abi: marketAbi,
    functionName: 'list',
    args: [tokenId, price],
    account
  })
  const hash = await walletClient.writeContract(request)
  return hash
}

async function buyNFTWithCallback(tokenId, price) {
  const { request } = await publicClient.simulateContract({
    address: addresses.BaseERC20,
    abi: erc20Abi,
    functionName: 'transferWithCallback',
    args: [addresses.NFTMarket, price, tokenId],
    account
  })
  const hash = await walletClient.writeContract(request)
  return hash
}

async function buyNFTTraditional(tokenId) {
  const listing = await publicClient.readContract({
    address: addresses.NFTMarket,
    abi: marketAbi,
    functionName: 'listings',
    args: [tokenId]
  })

  // First approve ERC20
  await approveERC20(addresses.NFTMarket, listing.price)

  // Then buy NFT
  const { request } = await publicClient.simulateContract({
    address: addresses.NFTMarket,
    abi: marketAbi,
    functionName: 'buyNFT',
    args: [tokenId],
    account
  })
  const hash = await walletClient.writeContract(request)
  return hash
}

// Read functions
async function getERC20Balance(address) {
  const balance = await publicClient.readContract({
    address: addresses.BaseERC20,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address]
  })
  return balance
}

async function getNFTOwner(tokenId) {
  const owner = await publicClient.readContract({
    address: addresses.MyNFT,
    abi: nftAbi,
    functionName: 'ownerOf',
    args: [tokenId]
  })
  return owner
}

async function getListing(tokenId) {
  const listing = await publicClient.readContract({
    address: addresses.NFTMarket,
    abi: marketAbi,
    functionName: 'listings',
    args: [tokenId]
  })
  return listing
}

// Example usage
async function main() {
  const command = process.argv[2]
  const args = process.argv.slice(3)

  switch (command) {
    case 'mint':
      const [to] = args
      console.log('Minting NFT to:', to)
      const mintHash = await mintNFT(to)
      console.log('Mint tx:', mintHash)
      break

    case 'list':
      const [tokenId, price] = args
      console.log('Listing NFT:', tokenId, 'for price:', price)
      const listHash = await listNFT(tokenId, BigInt(price))
      console.log('List tx:', listHash)
      break

    case 'buy-callback':
      const [buyTokenId, buyPrice] = args
      console.log('Buying NFT with callback:', buyTokenId, 'for:', buyPrice)
      const buyHash = await buyNFTWithCallback(BigInt(buyTokenId), BigInt(buyPrice))
      console.log('Buy tx:', buyHash)
      break

    case 'buy-traditional':
      const [traditionalTokenId] = args
      console.log('Buying NFT traditionally:', traditionalTokenId)
      const traditionalHash = await buyNFTTraditional(BigInt(traditionalTokenId))
      console.log('Buy tx:', traditionalHash)
      break

    case 'balance':
      const [balanceAddress] = args
      const balance = await getERC20Balance(balanceAddress)
      console.log('ERC20 balance:', balance.toString())
      break

    case 'owner':
      const [ownerTokenId] = args
      const owner = await getNFTOwner(ownerTokenId)
      console.log('NFT owner:', owner)
      break

    case 'get-listing':
      const [listingTokenId] = args
      const listing = await getListing(listingTokenId)
      console.log('Listing:', listing)
      break

    default:
      console.log(`
Available commands:
  mint <address>                    - Mint a new NFT to address
  list <tokenId> <price>           - List NFT for sale
  buy-callback <tokenId> <price>   - Buy NFT using callback method
  buy-traditional <tokenId>        - Buy NFT using traditional method
  balance <address>                - Get ERC20 balance of address
  owner <tokenId>                  - Get owner of NFT
  get-listing <tokenId>            - Get listing info for NFT
      `)
  }
}

main().catch(console.error)

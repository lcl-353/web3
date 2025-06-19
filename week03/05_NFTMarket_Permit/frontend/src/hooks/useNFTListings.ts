import { useState, useEffect } from 'react'
import { useReadContract, usePublicClient } from 'wagmi'
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/config/contracts'
import { NFTListing } from '@/types'

export function useNFTListings() {
  const [listings, setListings] = useState<NFTListing[]>([])
  const [loading, setLoading] = useState(true)
  const publicClient = usePublicClient()

  // 获取NFT列表数据
  useEffect(() => {
    const fetchListings = async () => {
      if (!publicClient) return
      
      setLoading(true)
      try {
        // 方法1: 尝试从事件日志中获取Listed事件
        const listedEvents = await fetchListedEvents()
        
        // 方法2: 如果事件获取失败，尝试检查已知的tokenId
        let fetchedListings: NFTListing[] = []
        
        if (listedEvents.length > 0) {
          fetchedListings = listedEvents
        } else {
          // 尝试检查前100个tokenId
          fetchedListings = await checkTokenIds(0, 100)
        }
        
        setListings(fetchedListings)
      } catch (error) {
        console.error('获取NFT列表失败:', error)
        setListings([])
      } finally {
        setLoading(false)
      }
    }

    fetchListings()
  }, [publicClient])

  // 从事件日志中获取Listed事件
  const fetchListedEvents = async (): Promise<NFTListing[]> => {
    if (!publicClient) return []
    
    try {
      // 获取最近的区块
      const latestBlock = await publicClient.getBlockNumber()
      const fromBlock = latestBlock > BigInt(50000) ? latestBlock - BigInt(50000) : BigInt(1) // 确保不小于区块1

      console.log('检查Listed事件范围:', fromBlock, 'to', latestBlock)

      // 获取Listed事件
      const logs = await publicClient.getLogs({
        address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
        event: {
          type: 'event',
          name: 'Listed',
          inputs: [
            { type: 'address', name: 'seller', indexed: true },
            { type: 'address', name: 'nftContract', indexed: false },
            { type: 'uint256', name: 'tokenId', indexed: false },
            { type: 'uint256', name: 'price', indexed: false },
            { type: 'address', name: 'paymentToken', indexed: false }
          ]
        },
        fromBlock,
        toBlock: latestBlock
      })

      console.log('找到Listed事件数量:', logs.length)

      const listings: NFTListing[] = []
      
      for (const log of logs) {
        try {
          console.log('处理Listed事件:', log.args)
          
          // 检查这个listing是否仍然活跃
          const listingData = await getListingData(
            log.args.nftContract!,
            log.args.tokenId!
          )
          
          if (listingData && listingData.isActive) {
            console.log('找到活跃listing:', listingData)
            listings.push(listingData)
          } else {
            console.log('Listing已失效或不存在:', log.args.nftContract, log.args.tokenId)
          }
        } catch (error) {
          console.error('处理Listed事件失败:', error)
          // 如果获取listing数据失败，跳过这个事件
          continue
        }
      }

      return listings
    } catch (error) {
      console.error('获取Listed事件失败:', error)
      return []
    }
  }

  // 检查指定范围内的tokenId
  const checkTokenIds = async (start: number, end: number): Promise<NFTListing[]> => {
    const listings: NFTListing[] = []
    
    console.log('检查tokenId范围:', start, 'to', end)
    
    for (let i = start; i <= end; i++) {
      try {
        const listing = await getListingData(
          CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
          BigInt(i)
        )
        
        if (listing && listing.isActive) {
          console.log('找到活跃tokenId:', i, listing)
          listings.push(listing)
        }
      } catch (error) {
        // 如果某个tokenId不存在，继续检查下一个
        continue
      }
    }
    
    return listings
  }

  // 获取单个NFT的列表数据
  const getListingData = async (
    nftContract: `0x${string}`,
    tokenId: bigint
  ): Promise<NFTListing | null> => {
    if (!publicClient) return null
    
    try {
      const result = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
        abi: CONTRACT_ABIS.NFT_MARKET,
        functionName: 'listings',
        args: [nftContract, tokenId]
      }) as any

      if (result && result.isActive) {
        return {
          seller: result.seller,
          nftContract: result.nftContract,
          tokenId: result.tokenId,
          price: result.price,
          paymentToken: result.paymentToken,
          isActive: result.isActive
        }
      }
      
      return null
    } catch (error) {
      return null
    }
  }

  // 刷新列表
  const refreshListings = async () => {
    if (!publicClient) return
    
    setLoading(true)
    try {
      const listedEvents = await fetchListedEvents()
      let fetchedListings: NFTListing[] = []
      
      if (listedEvents.length > 0) {
        fetchedListings = listedEvents
      } else {
        fetchedListings = await checkTokenIds(0, 100)
      }
      
      setListings(fetchedListings)
    } catch (error) {
      console.error('刷新NFT列表失败:', error)
    } finally {
      setLoading(false)
    }
  }

  return {
    listings,
    loading,
    refreshListings
  }
} 
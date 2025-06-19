'use client'

import { useState, useEffect } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi'
import { parseEther } from 'viem'
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/config/contracts'
import { Button } from '@/components/ui/Button'
import { formatAddress, formatPrice } from '@/lib/utils'
import { NFTListing } from '@/types'
import { useNFTListings } from '@/hooks/useNFTListings'

interface NFTListProps {
  onRefresh?: () => void
}

export function NFTList({ onRefresh }: NFTListProps) {
  const { address } = useAccount()
  const { listings, loading, refreshListings } = useNFTListings()
  const [isProcessing, setIsProcessing] = useState(false)
  const [statusMessage, setStatusMessage] = useState('')
  const [processingTokenId, setProcessingTokenId] = useState<bigint | null>(null)

  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  // 检查代币授权状态
  const { data: tokenAllowance, refetch: refetchTokenAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.PAYMENT_TOKEN as `0x${string}`,
    abi: CONTRACT_ABIS.ERC20,
    functionName: 'allowance',
    args: address ? [address, CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`] : undefined,
    query: {
      enabled: !!address
    }
  })

  // 购买NFT
  const handleBuyNFT = async (listing: NFTListing) => {
    try {
      setIsProcessing(true)
      setProcessingTokenId(listing.tokenId)
      setStatusMessage('检查代币授权状态...')

      const nftPrice = listing.price
      const currentAllowance = (tokenAllowance as bigint) || BigInt(0)
      
      // 检查代币授权额度是否足够
      if (currentAllowance < nftPrice) {
        setStatusMessage('正在授权代币给市场合约...')
        
        // 授权足够的代币
        await writeContract({
          address: CONTRACT_ADDRESSES.PAYMENT_TOKEN as `0x${string}`,
          abi: CONTRACT_ABIS.ERC20,
          functionName: 'approve',
          args: [
            CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
            nftPrice + parseEther('1000') // 授权NFT价格 + 额外1000代币
          ]
        })

        setStatusMessage('等待授权交易确认...')
        
        // 等待一段时间让状态更新
        await new Promise(resolve => setTimeout(resolve, 2000))
        await refetchTokenAllowance()
      }

      setStatusMessage('正在购买NFT...')
      
      // 执行购买操作
      await writeContract({
        address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
        abi: CONTRACT_ABIS.NFT_MARKET,
        functionName: 'purchase',
        args: [
          listing.nftContract as `0x${string}`,
          listing.tokenId
        ]
      })

      setStatusMessage('等待购买交易确认...')
      
    } catch (error: any) {
      console.error('购买NFT失败:', error)
      setStatusMessage(`购买失败: ${error.message || '未知错误'}`)
      setIsProcessing(false)
      setProcessingTokenId(null)
    }
  }

  // 交易成功后刷新列表
  useEffect(() => {
    if (isSuccess && isProcessing) {
      setStatusMessage('购买成功！')
      setIsProcessing(false)
      setProcessingTokenId(null)
      refreshListings()
      onRefresh?.()
      
      setTimeout(() => {
        setStatusMessage('')
      }, 3000)
    }
  }, [isSuccess, isProcessing, refreshListings, onRefresh])

  if (loading) {
    return (
      <div className="flex justify-center items-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (listings.length === 0) {
    return (
      <div className="text-center py-8">
        <div className="bg-gray-50 rounded-lg p-8">
          <div className="text-gray-400 text-6xl mb-4">📦</div>
          <h3 className="text-lg font-medium text-gray-900 mb-2">暂无NFT在售</h3>
          <p className="text-gray-600 mb-4">
            市场上还没有NFT被上架，成为第一个上架NFT的用户吧！
          </p>
        </div>
      </div>
    )
  }

  return (
    <div>
      {/* 状态消息 */}
      {statusMessage && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div className="flex items-center">
            {isProcessing && (
              <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2"></div>
            )}
            <p className="text-blue-800">{statusMessage}</p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {listings.map((listing, index) => {
          const isCurrentlyProcessing = processingTokenId === listing.tokenId
          const currentAllowance = (tokenAllowance as bigint) || BigInt(0)
          const hasEnoughAllowance = currentAllowance >= listing.price
          
          return (
            <div key={index} className="bg-white rounded-lg shadow-md overflow-hidden">
              {/* NFT图片占位符 */}
              <div className="w-full h-48 bg-gradient-to-br from-blue-400 to-purple-500 flex items-center justify-center">
                <span className="text-white text-2xl font-bold">NFT #{Number(listing.tokenId)}</span>
              </div>
              
              <div className="p-6">
                <h3 className="text-lg font-semibold mb-2">NFT #{Number(listing.tokenId)}</h3>
                
                <div className="space-y-2 mb-4">
                  <p className="text-gray-600">
                    <span className="font-medium">价格:</span> {formatPrice(listing.price)} ETH
                  </p>
                  <p className="text-gray-600">
                    <span className="font-medium">卖家:</span> {formatAddress(listing.seller)}
                  </p>
                  <p className="text-gray-600">
                    <span className="font-medium">合约:</span> {formatAddress(listing.nftContract)}
                  </p>
                </div>

                {/* 授权状态提示 */}
                <div className="mb-4 p-2 bg-gray-50 rounded-md">
                  <p className="text-xs text-gray-600">
                    <span className="font-medium">授权状态: </span>
                    <span className={hasEnoughAllowance ? 'text-green-600' : 'text-orange-600'}>
                      {hasEnoughAllowance ? '授权充足' : '需要授权'}
                    </span>
                  </p>
                </div>

                <Button
                  onClick={() => handleBuyNFT(listing)}
                  disabled={isPending || isConfirming || isCurrentlyProcessing || listing.seller.toLowerCase() === address?.toLowerCase()}
                  className="w-full"
                >
                  {listing.seller.toLowerCase() === address?.toLowerCase() 
                    ? '自己的NFT' 
                    : isCurrentlyProcessing || (isPending || isConfirming) 
                      ? '处理中...' 
                      : '购买'
                  }
                </Button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
} 
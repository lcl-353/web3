'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/config/contracts'
import { Button } from '@/components/ui/Button'
import { formatAddress } from '@/lib/utils'
import { UserNFT } from '@/types'

interface UserNFTsProps {
  onListNFT: (tokenId: string) => void
}

export function UserNFTs({ onListNFT }: UserNFTsProps) {
  const { address, isConnected } = useAccount()
  const [userNFTs, setUserNFTs] = useState<UserNFT[]>([])
  const [loading, setLoading] = useState(true)

  // 读取用户NFT余额
  const { data: balance } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
    abi: CONTRACT_ABIS.ERC721,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  // 获取用户NFT列表
  useEffect(() => {
    const fetchUserNFTs = async () => {
      if (!address || !balance) {
        setUserNFTs([])
        setLoading(false)
        return
      }

      setLoading(true)
      try {
        const nfts: UserNFT[] = []
        
        // 遍历用户的NFT
        for (let i = 0; i < Number(balance); i++) {
          // 这里需要调用tokenOfOwnerByIndex函数来获取tokenId
          // 由于示例ERC721合约可能没有这个函数，这里使用模拟数据
          const mockNFT: UserNFT = {
            tokenId: BigInt(i + 1),
            nftContract: CONTRACT_ADDRESSES.NFT_COLLECTION,
            owner: address,
            approved: '0x0000000000000000000000000000000000000000'
          }
          nfts.push(mockNFT)
        }
        
        setUserNFTs(nfts)
      } catch (error) {
        console.error('获取用户NFT失败:', error)
        setUserNFTs([])
      } finally {
        setLoading(false)
      }
    }

    fetchUserNFTs()
  }, [address, balance])

  if (!isConnected) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-600">请先连接钱包</p>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (userNFTs.length === 0) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-600">您还没有NFT</p>
      </div>
    )
  }

  return (
    <div>
      <h3 className="text-lg font-semibold mb-4">我的NFT ({userNFTs.length})</h3>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {userNFTs.map((nft, index) => (
          <div key={index} className="bg-white rounded-lg shadow-md overflow-hidden">
            {/* NFT图片占位符 */}
            <div className="w-full h-48 bg-gradient-to-br from-green-400 to-blue-500 flex items-center justify-center">
              <span className="text-white text-2xl font-bold">NFT #{Number(nft.tokenId)}</span>
            </div>
            
            <div className="p-6">
              <h4 className="text-lg font-semibold mb-2">NFT #{Number(nft.tokenId)}</h4>
              
              <div className="space-y-2 mb-4">
                <p className="text-gray-600">
                  <span className="font-medium">所有者:</span> {formatAddress(nft.owner)}
                </p>
                <p className="text-gray-600">
                  <span className="font-medium">合约:</span> {formatAddress(nft.nftContract)}
                </p>
                {nft.approved !== '0x0000000000000000000000000000000000000000' && (
                  <p className="text-gray-600">
                    <span className="font-medium">授权给:</span> {formatAddress(nft.approved)}
                  </p>
                )}
              </div>

              <div className="space-y-2">
                <Button
                  onClick={() => onListNFT(nft.tokenId.toString())}
                  variant="outline"
                  className="w-full"
                >
                  上架出售
                </Button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
} 
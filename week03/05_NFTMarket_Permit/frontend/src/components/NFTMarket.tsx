'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/config/contracts'
import { Button } from '@/components/ui/Button'
import { NFTList } from './NFTList'

export function NFTMarket() {
  const { address, isConnected } = useAccount()
  const [activeTab, setActiveTab] = useState('marketplace')
  
  // 表单状态
  const [listTokenId, setListTokenId] = useState('')
  const [listPrice, setListPrice] = useState('')
  const [buyTokenId, setBuyTokenId] = useState('')
  
  // 操作状态
  const [isProcessing, setIsProcessing] = useState(false)
  const [statusMessage, setStatusMessage] = useState('')
  
  // 用于防止重复执行的ref
  const processedTransactionRef = useRef<string | null>(null)

  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  // 读取用户ETH余额
  const { data: ethBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.PAYMENT_TOKEN as `0x${string}`,
    abi: CONTRACT_ABIS.ERC20,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      staleTime: 10000,
      refetchOnWindowFocus: false
    }
  })

  // 检查NFT授权状态
  const { data: nftApproval, refetch: refetchNftApproval } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
    abi: CONTRACT_ABIS.ERC721,
    functionName: 'getApproved',
    args: listTokenId ? [BigInt(listTokenId)] : undefined,
    query: {
      enabled: !!listTokenId && activeTab === 'list'
    }
  })

  // 检查ERC20授权状态
  const { data: tokenAllowance, refetch: refetchTokenAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.PAYMENT_TOKEN as `0x${string}`,
    abi: CONTRACT_ABIS.ERC20,
    functionName: 'allowance',
    args: address ? [address, CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`] : undefined,
    query: {
      enabled: !!address && activeTab === 'buy'
    }
  })

  // 获取NFT listing信息
  const { data: listingInfo } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
    abi: CONTRACT_ABIS.NFT_MARKET,
    functionName: 'listings',
    args: buyTokenId ? [CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`, BigInt(buyTokenId)] : undefined,
    query: {
      enabled: !!buyTokenId && activeTab === 'buy',
      staleTime: 10000,
      refetchOnWindowFocus: false
    }
  })

  // 上架NFT流程
  const handleListNFT = async () => {
    if (!listTokenId || !listPrice) {
      setStatusMessage('请填写Token ID和价格')
      return
    }

    try {
      setIsProcessing(true)
      setStatusMessage('检查NFT授权状态...')

      // 检查NFT是否已授权
      const isApproved = nftApproval === CONTRACT_ADDRESSES.NFT_MARKET
      
      if (!isApproved) {
        setStatusMessage('正在授权NFT给市场合约...')
        
        // 先执行授权交易
        await writeContract({
          address: CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
          abi: CONTRACT_ABIS.ERC721,
          functionName: 'approve',
          args: [
            CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
            BigInt(listTokenId)
          ]
        })

        // 设置等待授权交易确认的状态
        setStatusMessage('等待授权交易确认...')
        // 这里return，让useWaitForTransactionReceipt监听交易确认
        // 交易确认后会触发isSuccess，然后继续执行上架逻辑
        return
      }

      // 如果已经授权，直接执行上架
      await executeListTransaction()
      
    } catch (error: unknown) {
      console.error('上架NFT失败:', error)
      const errorMessage = error instanceof Error ? error.message : '未知错误'
      setStatusMessage(`上架失败: ${errorMessage}`)
      setIsProcessing(false)
    }
  }

  // 执行上架交易的独立函数
  const executeListTransaction = useCallback(async () => {
    try {
      setStatusMessage('正在上架NFT...')
      
      await writeContract({
        address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
        abi: CONTRACT_ABIS.NFT_MARKET,
        functionName: 'list',
        args: [
          CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
          BigInt(listTokenId),
          parseEther(listPrice),
          CONTRACT_ADDRESSES.PAYMENT_TOKEN as `0x${string}`
        ]
      })

      setStatusMessage('等待上架交易确认...')
    } catch (error: unknown) {
      console.error('上架交易失败:', error)
      const errorMessage = error instanceof Error ? error.message : '未知错误'
      setStatusMessage(`上架失败: ${errorMessage}`)
      setIsProcessing(false)
    }
  }, [writeContract, listTokenId, listPrice])

  // 购买NFT流程
  const handleBuyNFT = async () => {
    if (!buyTokenId) {
      setStatusMessage('请填写要购买的Token ID')
      return
    }

    if (!listingInfo || !Array.isArray(listingInfo) || listingInfo.length < 6 || !listingInfo[5]) {
      setStatusMessage('NFT未上架或已售出')
      return
    }

    try {
      setIsProcessing(true)
      setStatusMessage('检查代币授权状态...')

      const nftPrice = Array.isArray(listingInfo) && listingInfo.length > 3 ? listingInfo[3] as bigint : BigInt(0)
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

        setStatusMessage('等待代币授权交易确认...')
        // 返回，等待交易确认后再执行购买
        return
      }

      // 如果授权充足，直接执行购买
      await executePurchaseTransaction()
      
    } catch (error: unknown) {
      console.error('购买NFT失败:', error)
      const errorMessage = error instanceof Error ? error.message : '未知错误'
      setStatusMessage(`购买失败: ${errorMessage}`)
      setIsProcessing(false)
    }
  }

  // 执行购买交易的独立函数
  const executePurchaseTransaction = useCallback(async () => {
    try {
      setStatusMessage('正在购买NFT...')
      
      await writeContract({
        address: CONTRACT_ADDRESSES.NFT_MARKET as `0x${string}`,
        abi: CONTRACT_ABIS.NFT_MARKET,
        functionName: 'purchase',
        args: [
          CONTRACT_ADDRESSES.NFT_COLLECTION as `0x${string}`,
          BigInt(buyTokenId)
        ]
      })

      setStatusMessage('等待购买交易确认...')
    } catch (error: unknown) {
      console.error('购买交易失败:', error)
      const errorMessage = error instanceof Error ? error.message : '未知错误'
      setStatusMessage(`购买失败: ${errorMessage}`)
      setIsProcessing(false)
    }
  }, [writeContract, buyTokenId])

  // 监听交易成功 - 使用useEffect防止重复执行
  useEffect(() => {
    if (isSuccess && isProcessing && hash && processedTransactionRef.current !== hash) {
      // 标记这个交易已经处理过
      processedTransactionRef.current = hash
      
      // 检查是否是NFT授权交易完成
      if (statusMessage.includes('等待授权交易确认')) {
        setTimeout(async () => {
          setStatusMessage('授权成功，准备上架NFT...')
          await refetchNftApproval()
          
          // 等待状态更新后执行上架
          setTimeout(() => {
            console.log('执行上架交易')
            executeListTransaction()
          }, 1000)
        }, 0)
      }
      // 检查是否是代币授权交易完成
      else if (statusMessage.includes('等待代币授权交易确认')) {
        setTimeout(async () => {
          setStatusMessage('授权成功，准备购买NFT...')
          await refetchTokenAllowance()
          
          // 等待状态更新后执行购买
          setTimeout(() => {
            executePurchaseTransaction()
          }, 1000)
        }, 0)
      }
      // 主要交易完成
      else {
        setTimeout(() => {
          setStatusMessage('操作成功！')
          setIsProcessing(false)
          setListTokenId('')
          setListPrice('')
          setBuyTokenId('')
          
          setTimeout(() => {
            setStatusMessage('')
            // 重置processed标记，以便处理下一个交易
            processedTransactionRef.current = null
          }, 3000)
        }, 0)
      }
    }
  }, [isSuccess, isProcessing, hash, statusMessage, refetchNftApproval, refetchTokenAllowance, executeListTransaction, executePurchaseTransaction])

  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto p-6">
        <div className="text-center py-12">
          <h2 className="text-2xl font-bold text-gray-800 mb-4">NFT 市场</h2>
          <p className="text-gray-600 mb-6">请先连接钱包使用NFT市场功能</p>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto p-6">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-800 mb-2">NFT 市场</h1>
        <p className="text-gray-600">买卖和交易NFT</p>
      </div>

      {/* 状态栏 */}
      <div className="bg-white rounded-lg shadow-sm border p-4 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <span className="text-gray-600">我的地址:</span>
            <p className="font-mono text-xs break-all">{address}</p>
          </div>
          <div>
            <span className="text-gray-600">ETH余额:</span>
            <p className="font-medium">
              {ethBalance ? formatEther(ethBalance as bigint) : '0'} ETH
            </p>
          </div>
          <div>
            <span className="text-gray-600">合约地址:</span>
            <p className="font-mono text-xs break-all">{CONTRACT_ADDRESSES.NFT_MARKET}</p>
          </div>
        </div>
      </div>

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

      {/* 标签页 */}
      <div className="mb-6">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {[
              { id: 'marketplace', label: '市场' },
              { id: 'my-nfts', label: '我的NFT' },
              { id: 'list', label: '上架NFT' },
              { id: 'buy', label: '购买NFT' }
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-2 px-1 border-b-2 font-medium text-sm ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </nav>
        </div>
      </div>

      {/* 内容区域 */}
      <div className="bg-white rounded-lg shadow-sm border p-6">
        {activeTab === 'marketplace' && (
          <div>
            <h2 className="text-xl font-semibold mb-4">NFT 市场</h2>
            
            {/* 调试信息 */}
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <h3 className="font-medium text-yellow-800 mb-2">调试信息</h3>
              <div className="text-sm text-yellow-700 space-y-1">
                <p><strong>NFT Market合约:</strong> {CONTRACT_ADDRESSES.NFT_MARKET}</p>
                <p><strong>NFT Collection合约:</strong> {CONTRACT_ADDRESSES.NFT_COLLECTION}</p>
                <p><strong>Payment Token合约:</strong> {CONTRACT_ADDRESSES.PAYMENT_TOKEN}</p>
              </div>
            </div>
            
            <NFTList />
          </div>
        )}

        {activeTab === 'my-nfts' && (
          <div>
            <h2 className="text-xl font-semibold mb-4">我的 NFT</h2>
            <NFTList />
          </div>
        )}

        {activeTab === 'list' && (
          <div>
            <h2 className="text-xl font-semibold mb-4">上架 NFT</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Token ID
                </label>
                <input
                  type="number"
                  value={listTokenId}
                  onChange={(e) => setListTokenId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="输入要上架的NFT Token ID"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  价格 (ETH)
                </label>
                <input
                  type="number"
                  step="0.001"
                  value={listPrice}
                  onChange={(e) => setListPrice(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="输入价格"
                />
              </div>

              {listTokenId && (
                <div className="bg-gray-50 p-3 rounded-md">
                  <p className="text-sm text-gray-600 mb-2">授权状态检查:</p>
                  <p className="text-sm">
                    <span className="font-medium">NFT授权状态: </span>
                    <span className={nftApproval === CONTRACT_ADDRESSES.NFT_MARKET ? 'text-green-600' : 'text-red-600'}>
                      {nftApproval === CONTRACT_ADDRESSES.NFT_MARKET ? '已授权' : '未授权'}
                    </span>
                  </p>
                </div>
              )}
              
              <Button
                onClick={handleListNFT}
                disabled={!listTokenId || !listPrice || isProcessing || isPending || isConfirming}
                className="w-full"
              >
                {isProcessing || isPending || isConfirming ? '处理中...' : '上架NFT'}
              </Button>
            </div>
          </div>
        )}

        {activeTab === 'buy' && (
          <div>
            <h2 className="text-xl font-semibold mb-4">购买 NFT</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Token ID
                </label>
                <input
                  type="number"
                  value={buyTokenId}
                  onChange={(e) => setBuyTokenId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="输入要购买的NFT Token ID"
                />
              </div>



              {buyTokenId && listingInfo && Array.isArray(listingInfo) && listingInfo.length >= 6 && (
                <div className="bg-gray-50 p-4 rounded-md">
                  <h3 className="font-medium mb-2">NFT 信息</h3>
                  <div className="space-y-1 text-sm">
                    <p><span className="font-medium">卖家:</span> {String(listingInfo[0]).slice(0, 6)}...{String(listingInfo[0]).slice(-4)}</p>
                    <p><span className="font-medium">价格:</span> {formatEther(listingInfo[3] as bigint)} ETH</p>
                    <p><span className="font-medium">状态:</span> 
                      <span className={listingInfo[5] ? 'text-green-600' : 'text-red-600'}>
                        {listingInfo[5] ? ' 可购买' : ' 已售出'}
                      </span>
                    </p>
                  </div>
                  
                  <div className="mt-3 pt-3 border-t">
                    <p className="text-sm text-gray-600 mb-2">授权状态检查:</p>
                    <p className="text-sm">
                      <span className="font-medium">代币授权额度: </span>
                      <span className="text-blue-600">
                        {tokenAllowance ? formatEther(tokenAllowance as bigint) : '0'} ETH
                      </span>
                    </p>
                    <p className="text-sm">
                      <span className="font-medium">需要额度: </span>
                      <span className="text-orange-600">
                        {formatEther(listingInfo[3] as bigint)} ETH
                      </span>
                    </p>
                    <p className="text-sm">
                      <span className="font-medium">授权状态: </span>
                      <span className={(tokenAllowance as bigint || BigInt(0)) >= (listingInfo[3] as bigint) ? 'text-green-600' : 'text-red-600'}>
                        {(tokenAllowance as bigint || BigInt(0)) >= (listingInfo[3] as bigint) ? '授权充足' : '需要授权'}
                      </span>
                    </p>
                  </div>
                </div>
              )}
              
              <Button
                onClick={handleBuyNFT}
                disabled={!buyTokenId || isProcessing || isPending || isConfirming || !listingInfo || !Array.isArray(listingInfo) || listingInfo.length < 6 || !listingInfo[5]}
                className="w-full"
              >
                {isProcessing || isPending || isConfirming ? '处理中...' : '购买NFT'}
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
} 
'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther, parseUnits, formatUnits } from 'viem'
import SushiRouterABI from '../../abi/SushiRouter.json'
import ERC20ABI from '../../abi/ERC20.json'

// 合约地址（需要根据实际部署情况修改）
const SUSHI_ROUTER_ADDRESS = '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707'

interface TokenInfo {
  address: string
  symbol: string
  decimals: number
  balance: bigint
  allowance: bigint
}

interface LPTokenInfo {
  address: string
  balance: bigint
  allowance: bigint
  symbol: string
}

export function LiquidityManager() {
  const [mounted, setMounted] = useState(false)
  const { address, isConnected } = useAccount()
  const [activeTab, setActiveTab] = useState<'add' | 'remove'>('add')
  
  // 表单状态
  const [tokenA, setTokenA] = useState('')
  const [tokenB, setTokenB] = useState('')
  const [amountA, setAmountA] = useState('')
  const [amountB, setAmountB] = useState('')
  const [liquidity, setLiquidity] = useState('')
  
  // Token信息
  const [tokenAInfo, setTokenAInfo] = useState<TokenInfo | null>(null)
  const [tokenBInfo, setTokenBInfo] = useState<TokenInfo | null>(null)
  const [lpTokenInfo, setLpTokenInfo] = useState<LPTokenInfo | null>(null)

  const { writeContract, data: hash, isPending, error } = useWriteContract()
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    setMounted(true)
  }, [])

  // 读取Factory地址
  const { data: factoryAddress } = useReadContract({
    address: SUSHI_ROUTER_ADDRESS as `0x${string}`,
    abi: SushiRouterABI,
    functionName: 'factory'
  })

  // 读取配对地址
  const { data: pairAddress } = useReadContract({
    address: factoryAddress as `0x${string}`,
    abi: [
      {
        "type": "function",
        "name": "getPair",
        "inputs": [
          {"name": "tokenA", "type": "address"},
          {"name": "tokenB", "type": "address"}
        ],
        "outputs": [{"name": "", "type": "address"}],
        "stateMutability": "view"
      }
    ],
    functionName: 'getPair',
    args: [tokenA, tokenB],
    query: { enabled: !!factoryAddress && !!tokenA && !!tokenB && tokenA.length === 42 && tokenB.length === 42 }
  })

  // 读取LP代币余额
  const { data: lpBalance } = useReadContract({
    address: pairAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!pairAddress && !!address && pairAddress !== '0x0000000000000000000000000000000000000000' }
  })

  // 读取LP代币授权
  const { data: lpAllowance } = useReadContract({
    address: pairAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: [address, SUSHI_ROUTER_ADDRESS],
    query: { enabled: !!pairAddress && !!address && pairAddress !== '0x0000000000000000000000000000000000000000' }
  })

  // 读取LP代币符号
  const { data: lpSymbol } = useReadContract({
    address: pairAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: { enabled: !!pairAddress && pairAddress !== '0x0000000000000000000000000000000000000000' }
  })

  // 读取Token A信息
  const { data: tokenASymbol } = useReadContract({
    address: tokenA as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: { enabled: !!tokenA && tokenA.length === 42 }
  })

  const { data: tokenADecimals } = useReadContract({
    address: tokenA as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'decimals',
    query: { enabled: !!tokenA && tokenA.length === 42 }
  })

  const { data: tokenABalance } = useReadContract({
    address: tokenA as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!tokenA && !!address && tokenA.length === 42 }
  })

  const { data: tokenAAllowance } = useReadContract({
    address: tokenA as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: [address, SUSHI_ROUTER_ADDRESS],
    query: { enabled: !!tokenA && !!address && tokenA.length === 42 }
  })

  // 读取Token B信息
  const { data: tokenBSymbol } = useReadContract({
    address: tokenB as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: { enabled: !!tokenB && tokenB.length === 42 }
  })

  const { data: tokenBDecimals } = useReadContract({
    address: tokenB as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'decimals',
    query: { enabled: !!tokenB && tokenB.length === 42 }
  })

  const { data: tokenBBalance } = useReadContract({
    address: tokenB as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!tokenB && !!address && tokenB.length === 42 }
  })

  const { data: tokenBAllowance } = useReadContract({
    address: tokenB as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: [address, SUSHI_ROUTER_ADDRESS],
    query: { enabled: !!tokenB && !!address && tokenB.length === 42 }
  })

  // 更新Token信息
  useEffect(() => {
    if (tokenASymbol && tokenADecimals !== undefined && tokenABalance !== undefined && tokenAAllowance !== undefined) {
      setTokenAInfo({
        address: tokenA,
        symbol: tokenASymbol as string,
        decimals: tokenADecimals as number,
        balance: tokenABalance as bigint,
        allowance: tokenAAllowance as bigint
      })
    }
  }, [tokenA, tokenASymbol, tokenADecimals, tokenABalance, tokenAAllowance])

  useEffect(() => {
    if (tokenBSymbol && tokenBDecimals !== undefined && tokenBBalance !== undefined && tokenBAllowance !== undefined) {
      setTokenBInfo({
        address: tokenB,
        symbol: tokenBSymbol as string,
        decimals: tokenBDecimals as number,
        balance: tokenBBalance as bigint,
        allowance: tokenBAllowance as bigint
      })
    }
  }, [tokenB, tokenBSymbol, tokenBDecimals, tokenBBalance, tokenBAllowance])

  // 更新LP代币信息
  useEffect(() => {
    if (pairAddress && lpBalance !== undefined && lpAllowance !== undefined && lpSymbol) {
      setLpTokenInfo({
        address: pairAddress as string,
        balance: lpBalance as bigint,
        allowance: lpAllowance as bigint,
        symbol: lpSymbol as string
      })
    } else {
      setLpTokenInfo(null)
    }
  }, [pairAddress, lpBalance, lpAllowance, lpSymbol])

  // 复制功能
  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      alert('已复制到剪贴板')
    } catch (err) {
      console.error('复制失败:', err)
    }
  }

  // 授权Token
  const handleApprove = async (tokenAddress: string, isLPToken = false) => {
    try {
      await writeContract({
        address: tokenAddress as `0x${string}`,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [SUSHI_ROUTER_ADDRESS, parseEther('1000000')]
      })
    } catch (error) {
      console.error(`${isLPToken ? 'LP代币' : '代币'}授权失败:`, error)
    }
  }

  // 添加流动性
  const handleAddLiquidity = async () => {
    if (!tokenAInfo || !tokenBInfo || !amountA || !amountB) return

    try {
      const amountADesired = parseUnits(amountA, tokenAInfo.decimals)
      const amountBDesired = parseUnits(amountB, tokenBInfo.decimals)
      const amountAMin = amountADesired * BigInt(95) / BigInt(100)
      const amountBMin = amountBDesired * BigInt(95) / BigInt(100)
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200)

      await writeContract({
        address: SUSHI_ROUTER_ADDRESS as `0x${string}`,
        abi: SushiRouterABI,
        functionName: 'addLiquidity',
        args: [
          tokenA,
          tokenB,
          amountADesired,
          amountBDesired,
          amountAMin,
          amountBMin,
          address,
          deadline
        ]
      })
    } catch (error) {
      console.error('添加流动性失败:', error)
    }
  }

  // 移除流动性
  const handleRemoveLiquidity = async () => {
    if (!lpTokenInfo || !liquidity) return

    try {
      const liquidityAmount = parseEther(liquidity)
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200)

      await writeContract({
        address: SUSHI_ROUTER_ADDRESS as `0x${string}`,
        abi: SushiRouterABI,
        functionName: 'removeLiquidity',
        args: [
          tokenA,
          tokenB,
          liquidityAmount,
          BigInt(0),
          BigInt(0),
          address,
          deadline
        ]
      })
    } catch (error) {
      console.error('移除流动性失败:', error)
    }
  }

  // 在组件完全挂载前，始终显示相同的初始状态以避免hydration不匹配
  if (!mounted) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          流动性管理
        </h2>
        <div className="text-center text-gray-600 dark:text-gray-300">
          正在加载...
        </div>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          流动性管理
        </h2>
        <p className="text-center text-gray-600 dark:text-gray-300">
          请先连接钱包以使用流动性功能
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-md mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
        流动性管理
      </h2>

      {/* 选项卡 */}
      <div className="flex mb-6 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
        <button
          onClick={() => setActiveTab('add')}
          className={`flex-1 py-2 px-4 rounded-md font-medium transition-colors ${
            activeTab === 'add'
              ? 'bg-white dark:bg-gray-600 text-blue-600 dark:text-blue-400 shadow-sm'
              : 'text-gray-600 dark:text-gray-300'
          }`}
        >
          添加流动性
        </button>
        <button
          onClick={() => setActiveTab('remove')}
          className={`flex-1 py-2 px-4 rounded-md font-medium transition-colors ${
            activeTab === 'remove'
              ? 'bg-white dark:bg-gray-600 text-blue-600 dark:text-blue-400 shadow-sm'
              : 'text-gray-600 dark:text-gray-300'
          }`}
        >
          移除流动性
        </button>
      </div>

      {activeTab === 'add' && (
        <div className="space-y-4">
          {/* Token A */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token A 地址
            </label>
            <input
              type="text"
              value={tokenA}
              onChange={(e) => setTokenA(e.target.value)}
              placeholder="0x..."
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            {tokenAInfo && (
              <div className="mt-2 text-sm text-gray-600 dark:text-gray-400">
                <p>代币: {tokenAInfo.symbol}</p>
                <p>余额: {formatUnits(tokenAInfo.balance, tokenAInfo.decimals)}</p>
                <p>授权额度: {formatUnits(tokenAInfo.allowance, tokenAInfo.decimals)}</p>
              </div>
            )}
          </div>

          {/* Token A Amount */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token A 数量
            </label>
            <input
              type="number"
              value={amountA}
              onChange={(e) => setAmountA(e.target.value)}
              placeholder="0.0"
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>

          {/* Token B */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token B 地址
            </label>
            <input
              type="text"
              value={tokenB}
              onChange={(e) => setTokenB(e.target.value)}
              placeholder="0x..."
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            {tokenBInfo && (
              <div className="mt-2 text-sm text-gray-600 dark:text-gray-400">
                <p>代币: {tokenBInfo.symbol}</p>
                <p>余额: {formatUnits(tokenBInfo.balance, tokenBInfo.decimals)}</p>
                <p>授权额度: {formatUnits(tokenBInfo.allowance, tokenBInfo.decimals)}</p>
              </div>
            )}
          </div>

          {/* Token B Amount */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token B 数量
            </label>
            <input
              type="number"
              value={amountB}
              onChange={(e) => setAmountB(e.target.value)}
              placeholder="0.0"
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>

          {/* Token A Approve Button */}
          {tokenAInfo && tokenAInfo.allowance < parseUnits(amountA || '0', tokenAInfo.decimals) && (
            <button
              onClick={() => handleApprove(tokenA)}
              disabled={isPending}
              className="w-full py-2 px-4 bg-yellow-600 hover:bg-yellow-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
            >
              授权 Token A
            </button>
          )}

          {/* Token B Approve Button */}
          {tokenBInfo && tokenBInfo.allowance < parseUnits(amountB || '0', tokenBInfo.decimals) && (
            <button
              onClick={() => handleApprove(tokenB)}
              disabled={isPending}
              className="w-full py-2 px-4 bg-yellow-600 hover:bg-yellow-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
            >
              授权 Token B
            </button>
          )}

          {/* Add Liquidity Button */}
          <button
            onClick={handleAddLiquidity}
            disabled={
              isPending || 
              !tokenAInfo || 
              !tokenBInfo || 
              !amountA || 
              !amountB ||
              (tokenAInfo.allowance < parseUnits(amountA || '0', tokenAInfo.decimals)) ||
              (tokenBInfo.allowance < parseUnits(amountB || '0', tokenBInfo.decimals))
            }
            className="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
          >
            {isPending ? '添加中...' : '添加流动性'}
          </button>
        </div>
      )}

      {activeTab === 'remove' && (
        <div className="space-y-4">
          {/* Token A */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token A 地址
            </label>
            <input
              type="text"
              value={tokenA}
              onChange={(e) => setTokenA(e.target.value)}
              placeholder="0x..."
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>

          {/* Token B */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Token B 地址
            </label>
            <input
              type="text"
              value={tokenB}
              onChange={(e) => setTokenB(e.target.value)}
              placeholder="0x..."
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>

          {/* LP Token 信息显示 */}
          {lpTokenInfo && (
            <div className="p-3 bg-gray-50 dark:bg-gray-700 rounded-md">
              <h4 className="text-sm font-medium text-gray-900 dark:text-white mb-2">LP代币信息</h4>
              <div className="text-sm text-gray-600 dark:text-gray-400 space-y-1">
                <p>代币: {lpTokenInfo.symbol}</p>
                <p>余额: {formatEther(lpTokenInfo.balance)}</p>
                <p>授权额度: {formatEther(lpTokenInfo.allowance)}</p>
                <p 
                  className="text-xs font-mono break-all cursor-pointer hover:bg-gray-200 dark:hover:bg-gray-600 p-1 rounded"
                  onClick={() => copyToClipboard(lpTokenInfo.address)}
                  title="点击复制LP代币地址"
                >
                  地址: {lpTokenInfo.address}
                </p>
              </div>
            </div>
          )}

          {/* Liquidity Amount */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              流动性数量
            </label>
            <input
              type="number"
              value={liquidity}
              onChange={(e) => setLiquidity(e.target.value)}
              placeholder="0.0"
              className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            {lpTokenInfo && lpTokenInfo.balance > 0 && (
              <div className="mt-1 flex gap-2">
                <button
                  onClick={() => setLiquidity(formatEther(lpTokenInfo.balance / BigInt(4)))}
                  className="text-xs bg-gray-500 hover:bg-gray-600 text-white px-2 py-1 rounded"
                >
                  25%
                </button>
                <button
                  onClick={() => setLiquidity(formatEther(lpTokenInfo.balance / BigInt(2)))}
                  className="text-xs bg-gray-500 hover:bg-gray-600 text-white px-2 py-1 rounded"
                >
                  50%
                </button>
                <button
                  onClick={() => setLiquidity(formatEther(lpTokenInfo.balance * BigInt(3) / BigInt(4)))}
                  className="text-xs bg-gray-500 hover:bg-gray-600 text-white px-2 py-1 rounded"
                >
                  75%
                </button>
                <button
                  onClick={() => setLiquidity(formatEther(lpTokenInfo.balance))}
                  className="text-xs bg-gray-500 hover:bg-gray-600 text-white px-2 py-1 rounded"
                >
                  最大
                </button>
              </div>
            )}
          </div>

          {/* LP Token 授权按钮 */}
          {lpTokenInfo && lpTokenInfo.allowance < parseEther(liquidity || '0') && (
            <button
              onClick={() => handleApprove(lpTokenInfo.address, true)}
              disabled={isPending}
              className="w-full py-2 px-4 bg-orange-600 hover:bg-orange-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
            >
              授权 LP代币
            </button>
          )}

          {/* 交易对不存在提示 */}
          {tokenA && tokenB && tokenA.length === 42 && tokenB.length === 42 && !lpTokenInfo && (
            <div className="p-3 bg-yellow-50 dark:bg-yellow-900 rounded-md">
              <p className="text-sm text-yellow-800 dark:text-yellow-200">
                该交易对不存在或尚未创建流动性池
              </p>
            </div>
          )}

          {/* Remove Liquidity Button */}
          <button
            onClick={handleRemoveLiquidity}
            disabled={
              isPending || 
              !tokenA || 
              !tokenB || 
              !liquidity || 
              !lpTokenInfo ||
              lpTokenInfo.balance === BigInt(0) ||
              lpTokenInfo.allowance < parseEther(liquidity || '0')
            }
            className="w-full py-3 px-4 bg-red-600 hover:bg-red-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
          >
            {isPending ? '移除中...' : '移除流动性'}
          </button>
        </div>
      )}

      {/* 交易状态 */}
      {hash && (
        <div className="mt-4 p-3 bg-blue-100 dark:bg-blue-900 rounded-md">
          <div className="mb-2">
            <p className="text-sm font-medium text-blue-800 dark:text-blue-200 mb-1">
              交易哈希:
            </p>
            <div className="flex items-center gap-2 mb-2">
              <p 
                className="text-xs text-blue-700 dark:text-blue-300 font-mono break-all cursor-pointer hover:bg-blue-200 dark:hover:bg-blue-800 p-1 rounded flex-1"
                onClick={() => copyToClipboard(hash)}
                title="点击复制完整哈希"
              >
                {hash}
              </p>
              <button
                onClick={() => copyToClipboard(hash)}
                className="text-xs bg-blue-600 hover:bg-blue-700 text-white px-2 py-1 rounded transition-colors whitespace-nowrap"
                title="复制哈希"
              >
                复制
              </button>
            </div>
            <a
              href={`https://etherscan.io/tx/${hash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-blue-600 dark:text-blue-400 hover:underline"
            >
              在 Etherscan 上查看 ↗
            </a>
          </div>
          {isConfirming && (
            <p className="text-sm text-blue-600 dark:text-blue-300">确认中...</p>
          )}
          {isConfirmed && (
            <p className="text-sm text-green-600 dark:text-green-400">交易成功！</p>
          )}
        </div>
      )}

      {/* 错误信息 */}
      {error && (
        <div className="mt-4 p-3 bg-red-100 dark:bg-red-900 rounded-md">
          <p className="text-sm text-red-800 dark:text-red-200">
            错误: {error.message}
          </p>
        </div>
      )}
    </div>
  )
} 
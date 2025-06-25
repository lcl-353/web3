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

export function SwapManager() {
  const [mounted, setMounted] = useState(false)
  const { address, isConnected } = useAccount()
  
  // 表单状态
  const [tokenIn, setTokenIn] = useState('')
  const [tokenOut, setTokenOut] = useState('')
  const [amountIn, setAmountIn] = useState('')
  const [amountOut, setAmountOut] = useState('')
  const [slippage, setSlippage] = useState('0.5') // 默认0.5%滑点
  
  // Token信息
  const [tokenInInfo, setTokenInInfo] = useState<TokenInfo | null>(null)
  const [tokenOutInfo, setTokenOutInfo] = useState<TokenInfo | null>(null)

  const { writeContract, data: hash, isPending, error } = useWriteContract()
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    setMounted(true)
  }, [])

  // 读取Token In信息
  const { data: tokenInSymbol } = useReadContract({
    address: tokenIn as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: { enabled: !!tokenIn && tokenIn.length === 42 }
  })

  const { data: tokenInDecimals } = useReadContract({
    address: tokenIn as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'decimals',
    query: { enabled: !!tokenIn && tokenIn.length === 42 }
  })

  const { data: tokenInBalance } = useReadContract({
    address: tokenIn as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!tokenIn && !!address && tokenIn.length === 42 }
  })

  const { data: tokenInAllowance } = useReadContract({
    address: tokenIn as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: [address, SUSHI_ROUTER_ADDRESS],
    query: { enabled: !!tokenIn && !!address && tokenIn.length === 42 }
  })

  // 读取Token Out信息
  const { data: tokenOutSymbol } = useReadContract({
    address: tokenOut as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: { enabled: !!tokenOut && tokenOut.length === 42 }
  })

  const { data: tokenOutDecimals } = useReadContract({
    address: tokenOut as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'decimals',
    query: { enabled: !!tokenOut && tokenOut.length === 42 }
  })

  const { data: tokenOutBalance } = useReadContract({
    address: tokenOut as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!tokenOut && !!address && tokenOut.length === 42 }
  })

  // 获取swap输出数量
  const { data: amountsOut } = useReadContract({
    address: SUSHI_ROUTER_ADDRESS as `0x${string}`,
    abi: SushiRouterABI,
    functionName: 'getAmountsOut',
    args: [
      tokenInInfo ? parseUnits(amountIn || '0', tokenInInfo.decimals) : BigInt(0),
      [tokenIn, tokenOut]
    ],
    query: { 
      enabled: !!tokenIn && !!tokenOut && !!amountIn && !!tokenInInfo && 
               tokenIn.length === 42 && tokenOut.length === 42 && 
               parseFloat(amountIn) > 0
    }
  })

  // 更新Token In信息
  useEffect(() => {
    if (tokenInSymbol && tokenInDecimals !== undefined && tokenInBalance !== undefined && tokenInAllowance !== undefined) {
      setTokenInInfo({
        address: tokenIn,
        symbol: tokenInSymbol as string,
        decimals: tokenInDecimals as number,
        balance: tokenInBalance as bigint,
        allowance: tokenInAllowance as bigint
      })
    }
  }, [tokenIn, tokenInSymbol, tokenInDecimals, tokenInBalance, tokenInAllowance])

  // 更新Token Out信息
  useEffect(() => {
    if (tokenOutSymbol && tokenOutDecimals !== undefined && tokenOutBalance !== undefined) {
      setTokenOutInfo({
        address: tokenOut,
        symbol: tokenOutSymbol as string,
        decimals: tokenOutDecimals as number,
        balance: tokenOutBalance as bigint,
        allowance: BigInt(0) // 输出代币不需要授权
      })
    }
  }, [tokenOut, tokenOutSymbol, tokenOutDecimals, tokenOutBalance])

  // 更新输出数量
  useEffect(() => {
    if (amountsOut && Array.isArray(amountsOut) && amountsOut.length >= 2 && tokenOutInfo) {
      const outputAmount = amountsOut[1] as bigint
      setAmountOut(formatUnits(outputAmount, tokenOutInfo.decimals))
    } else {
      setAmountOut('')
    }
  }, [amountsOut, tokenOutInfo])

  // 复制功能
  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      alert('已复制到剪贴板')
    } catch (err) {
      console.error('复制失败:', err)
    }
  }

  // 交换输入输出代币
  const handleSwapTokens = () => {
    const tempToken = tokenIn
    const tempAmount = amountIn
    setTokenIn(tokenOut)
    setTokenOut(tempToken)
    setAmountIn(amountOut)
    setAmountOut(tempAmount)
  }

  // 授权Token
  const handleApprove = async () => {
    if (!tokenIn) return
    
    try {
      await writeContract({
        address: tokenIn as `0x${string}`,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [SUSHI_ROUTER_ADDRESS, parseEther('1000000')]
      })
    } catch (error) {
      console.error('授权失败:', error)
    }
  }

  // 执行Swap
  const handleSwap = async () => {
    if (!tokenInInfo || !tokenOutInfo || !amountIn || !amountOut) return

    try {
      const amountInWei = parseUnits(amountIn, tokenInInfo.decimals)
      const amountOutWei = parseUnits(amountOut, tokenOutInfo.decimals)
      
      // 计算最小输出（考虑滑点）
      const slippagePercent = parseFloat(slippage)
      const amountOutMin = amountOutWei * BigInt(Math.floor((100 - slippagePercent) * 100)) / BigInt(10000)
      
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200) // 20分钟后过期

      console.log('Swap参数:')
      console.log('amountIn:', amountInWei.toString())
      console.log('amountOutMin:', amountOutMin.toString())
      console.log('path:', [tokenIn, tokenOut])
      console.log('deadline:', deadline.toString())

      await writeContract({
        address: SUSHI_ROUTER_ADDRESS as `0x${string}`,
        abi: SushiRouterABI,
        functionName: 'swapExactTokensForTokens',
        args: [
          amountInWei,           // 输入数量
          amountOutMin,          // 最小输出数量（滑点保护）
          [tokenIn, tokenOut],   // 交易路径
          address,               // 接收地址
          deadline               // 截止时间
        ]
      })
    } catch (error) {
      console.error('Swap失败:', error)
    }
  }

  // 计算价格影响
  const calculatePriceImpact = () => {
    if (!amountIn || !amountOut || parseFloat(amountIn) === 0 || parseFloat(amountOut) === 0) {
      return null
    }
    // 这里可以添加更复杂的价格影响计算逻辑
    return null
  }

  // 在组件完全挂载前，始终显示相同的初始状态以避免hydration不匹配
  if (!mounted) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          代币交换
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
          代币交换
        </h2>
        <p className="text-center text-gray-600 dark:text-gray-300">
          请先连接钱包以使用交换功能
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-md mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
        代币交换
      </h2>

      <div className="space-y-4">
        {/* 输入代币 */}
        <div className="p-4 border border-gray-300 dark:border-gray-600 rounded-lg">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            卖出
          </label>
          
          {/* Token In 地址 */}
          <input
            type="text"
            value={tokenIn}
            onChange={(e) => setTokenIn(e.target.value)}
            placeholder="代币地址 0x..."
            className="w-full p-3 mb-3 border border-gray-200 dark:border-gray-500 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-sm"
          />

          {/* Token In 数量 */}
          <div className="flex items-center justify-between">
            <input
              type="number"
              value={amountIn}
              onChange={(e) => setAmountIn(e.target.value)}
              placeholder="0.0"
              className="flex-1 p-3 border-none bg-transparent text-2xl font-semibold text-gray-900 dark:text-white outline-none"
            />
            {tokenInInfo && (
              <div className="text-right">
                <div className="text-lg font-medium text-gray-900 dark:text-white">
                  {tokenInInfo.symbol}
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400">
                  余额: {formatUnits(tokenInInfo.balance, tokenInInfo.decimals)}
                </div>
              </div>
            )}
          </div>

          {/* 快速选择按钮 */}
          {tokenInInfo && tokenInInfo.balance > 0 && (
            <div className="flex gap-2 mt-2">
              <button
                onClick={() => setAmountIn(formatUnits(tokenInInfo.balance / BigInt(4), tokenInInfo.decimals))}
                className="text-xs bg-gray-200 dark:bg-gray-600 hover:bg-gray-300 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded"
              >
                25%
              </button>
              <button
                onClick={() => setAmountIn(formatUnits(tokenInInfo.balance / BigInt(2), tokenInInfo.decimals))}
                className="text-xs bg-gray-200 dark:bg-gray-600 hover:bg-gray-300 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded"
              >
                50%
              </button>
              <button
                onClick={() => setAmountIn(formatUnits(tokenInInfo.balance * BigInt(3) / BigInt(4), tokenInInfo.decimals))}
                className="text-xs bg-gray-200 dark:bg-gray-600 hover:bg-gray-300 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded"
              >
                75%
              </button>
              <button
                onClick={() => setAmountIn(formatUnits(tokenInInfo.balance, tokenInInfo.decimals))}
                className="text-xs bg-gray-200 dark:bg-gray-600 hover:bg-gray-300 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded"
              >
                最大
              </button>
            </div>
          )}
        </div>

        {/* 交换箭头 */}
        <div className="flex justify-center">
          <button
            onClick={handleSwapTokens}
            className="p-2 bg-blue-100 dark:bg-blue-900 hover:bg-blue-200 dark:hover:bg-blue-800 rounded-full transition-colors"
            title="交换代币位置"
          >
            <svg className="w-5 h-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
            </svg>
          </button>
        </div>

        {/* 输出代币 */}
        <div className="p-4 border border-gray-300 dark:border-gray-600 rounded-lg">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            买入
          </label>
          
          {/* Token Out 地址 */}
          <input
            type="text"
            value={tokenOut}
            onChange={(e) => setTokenOut(e.target.value)}
            placeholder="代币地址 0x..."
            className="w-full p-3 mb-3 border border-gray-200 dark:border-gray-500 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-sm"
          />

          {/* Token Out 数量（只读） */}
          <div className="flex items-center justify-between">
            <input
              type="text"
              value={amountOut}
              readOnly
              placeholder="0.0"
              className="flex-1 p-3 border-none bg-transparent text-2xl font-semibold text-gray-900 dark:text-white outline-none"
            />
            {tokenOutInfo && (
              <div className="text-right">
                <div className="text-lg font-medium text-gray-900 dark:text-white">
                  {tokenOutInfo.symbol}
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400">
                  余额: {formatUnits(tokenOutInfo.balance, tokenOutInfo.decimals)}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* 滑点设置 */}
        <div className="p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
          <div className="flex items-center justify-between mb-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
              滑点容忍度
            </label>
            <span className="text-sm text-gray-500 dark:text-gray-400">
              {slippage}%
            </span>
          </div>
          <div className="flex gap-2">
            {['0.1', '0.5', '1.0'].map((value) => (
              <button
                key={value}
                onClick={() => setSlippage(value)}
                className={`px-3 py-1 text-sm rounded ${
                  slippage === value
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-200 dark:bg-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-500'
                }`}
              >
                {value}%
              </button>
            ))}
            <input
              type="number"
              value={slippage}
              onChange={(e) => setSlippage(e.target.value)}
              step="0.1"
              min="0.1"
              max="50"
              className="flex-1 px-2 py-1 text-sm border border-gray-300 dark:border-gray-500 rounded bg-white dark:bg-gray-600 text-gray-900 dark:text-white"
            />
          </div>
        </div>

        {/* 交易信息 */}
        {amountIn && amountOut && tokenInInfo && tokenOutInfo && (
          <div className="p-3 bg-blue-50 dark:bg-blue-900 rounded-lg text-sm">
            <div className="flex justify-between items-center mb-1">
              <span className="text-gray-600 dark:text-gray-300">汇率</span>
              <span className="text-gray-900 dark:text-white">
                1 {tokenInInfo.symbol} ≈ {(parseFloat(amountOut) / parseFloat(amountIn)).toFixed(6)} {tokenOutInfo.symbol}
              </span>
            </div>
            <div className="flex justify-between items-center mb-1">
              <span className="text-gray-600 dark:text-gray-300">最小获得</span>
              <span className="text-gray-900 dark:text-white">
                {(parseFloat(amountOut) * (100 - parseFloat(slippage)) / 100).toFixed(6)} {tokenOutInfo.symbol}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-600 dark:text-gray-300">路径</span>
              <span className="text-gray-900 dark:text-white">
                {tokenInInfo.symbol} → {tokenOutInfo.symbol}
              </span>
            </div>
          </div>
        )}

        {/* 授权按钮 */}
        {tokenInInfo && tokenInInfo.allowance < parseUnits(amountIn || '0', tokenInInfo.decimals) && (
          <button
            onClick={handleApprove}
            disabled={isPending}
            className="w-full py-3 px-4 bg-yellow-600 hover:bg-yellow-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
          >
            {isPending ? '授权中...' : `授权 ${tokenInInfo.symbol}`}
          </button>
        )}

        {/* Swap按钮 */}
        <button
          onClick={handleSwap}
          disabled={
            isPending ||
            !tokenInInfo ||
            !tokenOutInfo ||
            !amountIn ||
            !amountOut ||
            parseFloat(amountIn) === 0 ||
            tokenInInfo.balance < parseUnits(amountIn || '0', tokenInInfo.decimals) ||
            tokenInInfo.allowance < parseUnits(amountIn || '0', tokenInInfo.decimals)
          }
          className="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 text-white rounded-md font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending 
            ? '交换中...' 
            : !tokenInInfo || !tokenOutInfo 
              ? '输入代币地址'
              : !amountIn || parseFloat(amountIn) === 0
                ? '输入数量'
                : tokenInInfo.balance < parseUnits(amountIn || '0', tokenInInfo.decimals)
                  ? '余额不足'
                  : '交换'
          }
        </button>
      </div>

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
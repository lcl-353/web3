'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther, parseUnits, formatUnits } from 'viem'
import MasterChefABI from '../../abi/MasterChef.json'
import SushiTokenABI from '../../abi/SushiToken.json'
import ERC20ABI from '../../abi/ERC20.json'

// 合约地址（需要根据实际部署情况修改）
const MASTERCHEF_ADDRESS = '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853' // 需要替换为实际MasterChef地址
const SUSHI_TOKEN_ADDRESS = '0x0165878A594ca255338adfa4d48449f69242Eb8F' // 需要替换为实际SushiToken地址

interface PoolInfo {
  pid: number
  lpToken: string
  allocPoint: bigint
  lastRewardBlock: bigint
  accSushiPerShare: bigint
}

export function FarmingManager() {
  const [mounted, setMounted] = useState(false)
  const { address, isConnected } = useAccount()
  const [selectedPool, setSelectedPool] = useState<number | null>(null)
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [pools, setPools] = useState<PoolInfo[]>([])

  const { writeContract, data: hash, isPending, error } = useWriteContract()
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    setMounted(true)
  }, [])

  // 读取池子数量
  const { data: poolLength } = useReadContract({
    address: MASTERCHEF_ADDRESS as `0x${string}`,
    abi: MasterChefABI,
    functionName: 'poolLength'
  })

  // 读取SushiToken信息
  const { data: sushiSymbol } = useReadContract({
    address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
    abi: SushiTokenABI,
    functionName: 'symbol'
  })

  const { data: sushiBalance } = useReadContract({
    address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
    abi: SushiTokenABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!address }
  })

  const { data: sushiPerBlock } = useReadContract({
    address: MASTERCHEF_ADDRESS as `0x${string}`,
    abi: MasterChefABI,
    functionName: 'sushiPerBlock'
  })

  const { data: totalAllocPoint } = useReadContract({
    address: MASTERCHEF_ADDRESS as `0x${string}`,
    abi: MasterChefABI,
    functionName: 'totalAllocPoint'
  })

  // 复制功能
  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      alert('已复制到剪贴板')
    } catch (err) {
      console.error('复制失败:', err)
    }
  }

  // 授权LP Token
  const handleApproveLPToken = async (lpTokenAddress: string) => {
    try {
      await writeContract({
        address: lpTokenAddress as `0x${string}`,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [MASTERCHEF_ADDRESS, parseEther('1000000')]
      })
    } catch (error) {
      console.error('授权失败:', error)
    }
  }

  // 存入LP Token
  const handleDeposit = async (pid: number) => {
    if (!depositAmount) return

    try {
      const amount = parseEther(depositAmount)
      await writeContract({
        address: MASTERCHEF_ADDRESS as `0x${string}`,
        abi: MasterChefABI,
        functionName: 'deposit',
        args: [BigInt(pid), amount]
      })
    } catch (error) {
      console.error('存入失败:', error)
    }
  }

  // 提取LP Token
  const handleWithdraw = async (pid: number) => {
    if (!withdrawAmount) return

    try {
      const amount = parseEther(withdrawAmount)
      await writeContract({
        address: MASTERCHEF_ADDRESS as `0x${string}`,
        abi: MasterChefABI,
        functionName: 'withdraw',
        args: [BigInt(pid), amount]
      })
    } catch (error) {
      console.error('提取失败:', error)
    }
  }

  // 只领取奖励
  const handleHarvest = async (pid: number) => {
    try {
      await writeContract({
        address: MASTERCHEF_ADDRESS as `0x${string}`,
        abi: MasterChefABI,
        functionName: 'withdraw',
        args: [BigInt(pid), BigInt(0)]
      })
    } catch (error) {
      console.error('领取奖励失败:', error)
    }
  }

  // 紧急提取
  const handleEmergencyWithdraw = async (pid: number) => {
    try {
      await writeContract({
        address: MASTERCHEF_ADDRESS as `0x${string}`,
        abi: MasterChefABI,
        functionName: 'emergencyWithdraw',
        args: [BigInt(pid)]
      })
    } catch (error) {
      console.error('紧急提取失败:', error)
    }
  }

  // 为每个池子创建单独的组件来读取数据
  const PoolCard = ({ poolId }: { poolId: number }) => {
    // 读取具体池子信息
    const { data: poolInfo } = useReadContract({
      address: MASTERCHEF_ADDRESS as `0x${string}`,
      abi: MasterChefABI,
      functionName: 'poolInfo',
      args: [BigInt(poolId)]
    })

    // 读取用户信息
    const { data: userInfo } = useReadContract({
      address: MASTERCHEF_ADDRESS as `0x${string}`,
      abi: MasterChefABI,
      functionName: 'userInfo',
      args: [BigInt(poolId), address],
      query: { enabled: !!address }
    })

    // 读取待领取奖励
    const { data: pendingReward } = useReadContract({
      address: MASTERCHEF_ADDRESS as `0x${string}`,
      abi: MasterChefABI,
      functionName: 'pendingSushi',
      args: [BigInt(poolId), address],
      query: { enabled: !!address }
    })

    // 从poolInfo中提取LP token地址
    const lpTokenAddress = poolInfo ? (poolInfo as [string, bigint, bigint, bigint])[0] : ''
    const allocPoint = poolInfo ? (poolInfo as [string, bigint, bigint, bigint])[1] : BigInt(0)
    
    // 读取LP Token信息
    const { data: lpTokenSymbol } = useReadContract({
      address: lpTokenAddress as `0x${string}`,
      abi: ERC20ABI,
      functionName: 'symbol',
      query: { enabled: !!lpTokenAddress && lpTokenAddress !== '0x0000000000000000000000000000000000000000' }
    })

    const { data: lpTokenBalance } = useReadContract({
      address: lpTokenAddress as `0x${string}`,
      abi: ERC20ABI,
      functionName: 'balanceOf',
      args: [address],
      query: { enabled: !!address && !!lpTokenAddress && lpTokenAddress !== '0x0000000000000000000000000000000000000000' }
    })

    const { data: lpTokenAllowance } = useReadContract({
      address: lpTokenAddress as `0x${string}`,
      abi: ERC20ABI,
      functionName: 'allowance',
      args: [address, MASTERCHEF_ADDRESS],
      query: { enabled: !!address && !!lpTokenAddress && lpTokenAddress !== '0x0000000000000000000000000000000000000000' }
    })

    const userAmount = userInfo ? (userInfo as [bigint, bigint])[0] : BigInt(0)
    const pending = pendingReward as bigint || BigInt(0)
    const balance = lpTokenBalance as bigint || BigInt(0)
    const allowance = lpTokenAllowance as bigint || BigInt(0)

    // 计算APY（简化版本）
    const calculateAPY = () => {
      if (!allocPoint || !sushiPerBlock || !totalAllocPoint || totalAllocPoint === BigInt(0)) return '0'
      
      const poolShare = Number(allocPoint) / Number(totalAllocPoint)
      const sushiPerDay = Number(formatEther(sushiPerBlock as bigint)) * 24 * 60 * 60 / 12
      const poolSushiPerDay = sushiPerDay * poolShare
      
      return (poolSushiPerDay * 365 * 100).toFixed(2)
    }

    // 如果池子信息还没加载，显示加载状态
    if (!poolInfo) {
      return (
        <div className="p-4 border border-gray-300 dark:border-gray-600 rounded-lg">
          <div className="animate-pulse">
            <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-2"></div>
            <div className="h-3 bg-gray-200 dark:bg-gray-700 rounded w-1/2 mb-4"></div>
            <div className="h-10 bg-gray-200 dark:bg-gray-700 rounded"></div>
          </div>
        </div>
      )
    }

    return (
      <div className="p-4 border border-gray-300 dark:border-gray-600 rounded-lg">
        <div className="flex justify-between items-start mb-4">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
              池子 #{poolId}
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              {lpTokenSymbol || 'LP Token'}
            </p>
            {lpTokenAddress && (
              <p 
                className="text-xs font-mono text-gray-500 dark:text-gray-400 cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-700 p-1 rounded mt-1 break-all"
                onClick={() => copyToClipboard(lpTokenAddress)}
                title="点击复制LP Token地址"
              >
                📍 {lpTokenAddress}
              </p>
            )}
          </div>
          <div className="text-right">
            <div className="text-lg font-bold text-green-600 dark:text-green-400">
              {calculateAPY()}% APY
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-400">
              分配点数: {allocPoint.toString()}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
          <div>
            <p className="text-gray-600 dark:text-gray-400">我的质押</p>
            <p className="font-semibold text-gray-900 dark:text-white">
              {formatEther(userAmount)} LP
            </p>
          </div>
          <div>
            <p className="text-gray-600 dark:text-gray-400">待领取奖励</p>
            <p className="font-semibold text-green-600 dark:text-green-400">
              {formatEther(pending)} SUSHI
            </p>
          </div>
          <div>
            <p className="text-gray-600 dark:text-gray-400">可用余额</p>
            <p className="font-semibold text-gray-900 dark:text-white">
              {formatEther(balance)} LP
            </p>
          </div>
          <div>
            <p className="text-gray-600 dark:text-gray-400">授权状态</p>
            <p className={`font-semibold ${allowance > BigInt(0) ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
              {allowance > BigInt(0) ? '已授权' : '未授权'}
            </p>
          </div>
        </div>

        {selectedPool === poolId ? (
          <div className="space-y-3">
            {/* 存入部分 */}
            <div className="p-3 bg-blue-50 dark:bg-blue-900 rounded-lg">
              <h4 className="font-medium text-blue-900 dark:text-blue-100 mb-2">存入质押</h4>
              <div className="flex gap-2 mb-2">
                <input
                  type="number"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  placeholder="0.0"
                  className="flex-1 p-2 border border-blue-300 dark:border-blue-600 rounded bg-white dark:bg-blue-800 text-gray-900 dark:text-white"
                />
                <button
                  onClick={() => setDepositAmount(formatEther(balance))}
                  className="px-3 py-2 text-sm bg-blue-200 dark:bg-blue-700 text-blue-800 dark:text-blue-200 rounded hover:bg-blue-300 dark:hover:bg-blue-600"
                >
                  最大
                </button>
              </div>
              
              {allowance < parseEther(depositAmount || '0') && (
                <button
                  onClick={() => handleApproveLPToken(lpTokenAddress)}
                  disabled={isPending}
                  className="w-full py-2 px-4 mb-2 bg-yellow-600 hover:bg-yellow-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
                >
                  {isPending ? '授权中...' : '授权 LP Token'}
                </button>
              )}

              <button
                onClick={() => handleDeposit(poolId)}
                disabled={
                  isPending || 
                  !depositAmount || 
                  balance < parseEther(depositAmount || '0') ||
                  allowance < parseEther(depositAmount || '0')
                }
                className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
              >
                {isPending ? '存入中...' : '存入质押'}
              </button>
            </div>

            {/* 提取部分 */}
            <div className="p-3 bg-orange-50 dark:bg-orange-900 rounded-lg">
              <h4 className="font-medium text-orange-900 dark:text-orange-100 mb-2">提取质押</h4>
              <div className="flex gap-2 mb-2">
                <input
                  type="number"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                  placeholder="0.0"
                  className="flex-1 p-2 border border-orange-300 dark:border-orange-600 rounded bg-white dark:bg-orange-800 text-gray-900 dark:text-white"
                />
                <button
                  onClick={() => setWithdrawAmount(formatEther(userAmount))}
                  className="px-3 py-2 text-sm bg-orange-200 dark:bg-orange-700 text-orange-800 dark:text-orange-200 rounded hover:bg-orange-300 dark:hover:bg-orange-600"
                >
                  最大
                </button>
              </div>
              
              <button
                onClick={() => handleWithdraw(poolId)}
                disabled={
                  isPending || 
                  !withdrawAmount || 
                  userAmount < parseEther(withdrawAmount || '0')
                }
                className="w-full py-2 px-4 bg-orange-600 hover:bg-orange-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
              >
                {isPending ? '提取中...' : '提取质押'}
              </button>
            </div>

            {/* 操作按钮 */}
            <div className="flex gap-2">
              <button
                onClick={() => handleHarvest(poolId)}
                disabled={isPending || pending === BigInt(0)}
                className="flex-1 py-2 px-4 bg-green-600 hover:bg-green-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
              >
                {isPending ? '领取中...' : `领取奖励 (${formatEther(pending)} SUSHI)`}
              </button>
              
              <button
                onClick={() => handleEmergencyWithdraw(poolId)}
                disabled={isPending || userAmount === BigInt(0)}
                className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-md font-medium transition-colors disabled:opacity-50"
                title="紧急提取（放弃奖励）"
              >
                紧急提取
              </button>
            </div>

            <button
              onClick={() => setSelectedPool(null)}
              className="w-full py-2 px-4 bg-gray-500 hover:bg-gray-600 text-white rounded-md font-medium transition-colors"
            >
              收起
            </button>
          </div>
        ) : (
          <button
            onClick={() => setSelectedPool(poolId)}
            className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 text-white rounded-md font-medium transition-colors"
          >
            管理质押
          </button>
        )}
      </div>
    )
  }

  // 在组件完全挂载前，始终显示相同的初始状态以避免hydration不匹配
  if (!mounted) {
    return (
      <div className="max-w-4xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          流动性挖矿
        </h2>
        <div className="text-center text-gray-600 dark:text-gray-300">
          正在加载...
        </div>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          流动性挖矿
        </h2>
        <p className="text-center text-gray-600 dark:text-gray-300">
          请先连接钱包以使用挖矿功能
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
        流动性挖矿
      </h2>

      {/* 挖矿概览 */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="p-4 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg text-white">
          <h3 className="text-lg font-semibold mb-2">我的SUSHI余额</h3>
          <p className="text-2xl font-bold">
            {sushiBalance ? formatEther(sushiBalance as bigint) : '0.00'} {sushiSymbol || 'SUSHI'}
          </p>
        </div>
        
        <div className="p-4 bg-gradient-to-r from-green-500 to-teal-600 rounded-lg text-white">
          <h3 className="text-lg font-semibold mb-2">每区块奖励</h3>
          <p className="text-2xl font-bold">
            {sushiPerBlock ? formatEther(sushiPerBlock as bigint) : '0.00'} SUSHI
          </p>
        </div>
        
        <div className="p-4 bg-gradient-to-r from-orange-500 to-red-600 rounded-lg text-white">
          <h3 className="text-lg font-semibold mb-2">活跃池子数量</h3>
          <p className="text-2xl font-bold">
            {poolLength ? poolLength.toString() : '0'}
          </p>
        </div>
      </div>

      {/* 池子列表 */}
      <div className="space-y-4">
        <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          挖矿池列表
        </h3>
        
        {poolLength && Number(poolLength) > 0 ? (
          <div className="grid gap-4">
            {Array.from({ length: Number(poolLength) }, (_, index) => (
              <PoolCard key={index} poolId={index} />
            ))}
          </div>
        ) : (
          <div className="text-center py-8">
            <p className="text-gray-600 dark:text-gray-400">
              {poolLength === undefined ? '正在加载挖矿池...' : '暂无可用的挖矿池'}
            </p>
          </div>
        )}
      </div>

      {/* 交易状态 */}
      {hash && (
        <div className="mt-6 p-4 bg-blue-100 dark:bg-blue-900 rounded-md">
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
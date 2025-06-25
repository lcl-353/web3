'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther, parseUnits, formatUnits, encodeFunctionData } from 'viem'
import SimpleDAOABI from '../../abi/SimpleDAO.json'
import SushiTokenABI from '../../abi/SushiToken.json'
import MasterChefABI from '../../abi/MasterChef.json'

// 合约地址（需要根据实际部署情况修改）
const DAO_ADDRESS = '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6' // 需要替换为实际DAO地址
const SUSHI_TOKEN_ADDRESS = '0x0165878A594ca255338adfa4d48449f69242Eb8F' // 需要替换为实际SushiToken地址
const MASTERCHEF_ADDRESS = '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853' // 需要替换为实际MasterChef地址

// 提案状态枚举
enum ProposalState {
  Pending = 0,
  Active = 1,
  Canceled = 2,
  Defeated = 3,
  Succeeded = 4,
  Queued = 5,
  Expired = 6,
  Executed = 7
}

// 投票类型
enum VoteType {
  Against = 0,
  For = 1,
  Abstain = 2
}

interface Proposal {
  id: bigint
  proposer: string
  target: string
  value: bigint
  data: string
  description: string
  startTime: bigint
  endTime: bigint
  executionTime: bigint
  forVotes: bigint
  againstVotes: bigint
  abstainVotes: bigint
  executed: boolean
  canceled: boolean
}

export function DAOGovernance() {
  const [mounted, setMounted] = useState(false)
  const { address, isConnected } = useAccount()
  const [activeTab, setActiveTab] = useState<'proposals' | 'create' | 'delegate'>('proposals')
  
  // 创建提案的表单状态
  const [proposalDescription, setProposalDescription] = useState('')
  const [proposalFunction, setProposalFunction] = useState('updateSushiPerBlock')
  const [functionParams, setFunctionParams] = useState('')
  
  // 委托状态
  const [delegateAddress, setDelegateAddress] = useState('')
  
  const { data: hash, isPending, writeContract } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    setMounted(true)
  }, [])

  // 复制哈希到剪贴板
  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      alert('地址已复制到剪贴板')
    } catch (err) {
      console.error('复制失败:', err)
    }
  }

  // 读取用户的SUSHI余额
  const { data: sushiBalance } = useReadContract({
    address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
    abi: SushiTokenABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!address && mounted }
  })

  // 读取用户的投票权
  const { data: votingPower } = useReadContract({
    address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
    abi: SushiTokenABI,
    functionName: 'getVotes',
    args: [address],
    query: { enabled: !!address && mounted }
  })

  // 读取用户的委托对象
  const { data: delegate } = useReadContract({
    address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
    abi: SushiTokenABI,
    functionName: 'delegates',
    args: [address],
    query: { enabled: !!address && mounted }
  })

  // 读取提案数量
  const { data: proposalCount } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'proposalCount',
    query: { enabled: mounted }
  })

  // 读取治理参数
  const { data: proposalThreshold } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'PROPOSAL_THRESHOLD',
    query: { enabled: mounted }
  })

  const { data: quorumPercentage } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'QUORUM_PERCENTAGE',
    query: { enabled: mounted }
  })

  const { data: votingDelay } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'VOTING_DELAY',
    query: { enabled: mounted }
  })

  const { data: votingPeriod } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'VOTING_PERIOD',
    query: { enabled: mounted }
  })

  // 委托投票权
  const handleDelegate = async () => {
    if (!delegateAddress) return
    
    try {
      await writeContract({
        address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
        abi: SushiTokenABI,
        functionName: 'delegate',
        args: [delegateAddress as `0x${string}`]
      })
    } catch (error) {
      console.error('委托失败:', error)
    }
  }

  // 自委托（委托给自己）
  const handleSelfDelegate = async () => {
    if (!address) return
    
    try {
      await writeContract({
        address: SUSHI_TOKEN_ADDRESS as `0x${string}`,
        abi: SushiTokenABI,
        functionName: 'delegate',
        args: [address]
      })
    } catch (error) {
      console.error('自委托失败:', error)
    }
  }

  // 创建提案
  const handleCreateProposal = async () => {
    if (!proposalDescription || !functionParams) return
    
    try {
      let calldata: `0x${string}`
      
      // 根据选择的函数编码calldata
      switch (proposalFunction) {
        case 'updateSushiPerBlock':
          const newSushiPerBlock = parseEther(functionParams)
          calldata = encodeFunctionData({
            abi: MasterChefABI,
            functionName: 'updateSushiPerBlock',
            args: [newSushiPerBlock, true]
          })
          break
        case 'add':
          const [allocPoint, lpToken] = functionParams.split(',')
          calldata = encodeFunctionData({
            abi: MasterChefABI,
            functionName: 'add',
            args: [BigInt(allocPoint.trim()), lpToken.trim() as `0x${string}`, true]
          })
          break
        case 'set':
          const [pid, newAllocPoint] = functionParams.split(',')
          calldata = encodeFunctionData({
            abi: MasterChefABI,
            functionName: 'set',
            args: [BigInt(pid.trim()), BigInt(newAllocPoint.trim()), true]
          })
          break
        default:
          throw new Error('不支持的函数')
      }

      await writeContract({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SimpleDAOABI,
        functionName: 'propose',
        args: [
          MASTERCHEF_ADDRESS as `0x${string}`,
          BigInt(0), // value
          calldata,
          proposalDescription
        ]
      })
    } catch (error) {
      console.error('创建提案失败:', error)
    }
  }

  // 投票
  const handleVote = async (proposalId: number, support: VoteType) => {
    try {
      await writeContract({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SimpleDAOABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support]
      })
    } catch (error) {
      console.error('投票失败:', error)
    }
  }

  // 将提案加入执行队列
  const handleQueue = async (proposalId: number) => {
    try {
      await writeContract({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SimpleDAOABI,
        functionName: 'queue',
        args: [BigInt(proposalId)]
      })
    } catch (error) {
      console.error('加入队列失败:', error)
    }
  }

  // 执行提案
  const handleExecute = async (proposalId: number) => {
    try {
      await writeContract({
        address: DAO_ADDRESS as `0x${string}`,
        abi: SimpleDAOABI,
        functionName: 'execute',
        args: [BigInt(proposalId)]
      })
    } catch (error) {
      console.error('执行提案失败:', error)
    }
  }

  // 获取状态名称
  const getStateName = (state: number) => {
    const states = ['等待中', '投票中', '已取消', '被否决', '已通过', '队列中', '已过期', '已执行']
    return states[state] || '未知'
  }

  // 获取状态颜色
  const getStateColor = (state: number) => {
    const colors = [
      'bg-gray-100 text-gray-800',
      'bg-blue-100 text-blue-800',
      'bg-red-100 text-red-800',
      'bg-red-100 text-red-800',
      'bg-green-100 text-green-800',
      'bg-yellow-100 text-yellow-800',
      'bg-gray-100 text-gray-800',
      'bg-green-100 text-green-800'
    ]
    return colors[state] || 'bg-gray-100 text-gray-800'
  }

  if (!mounted) {
    return (
      <div className="max-w-4xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          DAO治理系统
        </h2>
        <p className="text-center text-gray-600 dark:text-gray-300">加载中...</p>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-6 text-center text-gray-900 dark:text-white">
          DAO治理系统
        </h2>
        <p className="text-center text-gray-600 dark:text-gray-300">
          请先连接钱包以使用DAO治理功能
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
      <h2 className="text-3xl font-bold mb-6 text-center text-gray-900 dark:text-white">
        🏛️ DAO治理系统
      </h2>

      {/* 用户信息面板 */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-gradient-to-r from-blue-500 to-purple-600 text-white p-4 rounded-lg">
          <h3 className="text-sm font-medium opacity-90">SUSHI余额</h3>
          <p className="text-2xl font-bold">
            {sushiBalance ? formatEther(sushiBalance) : '0'} SUSHI
          </p>
        </div>
        <div className="bg-gradient-to-r from-green-500 to-blue-500 text-white p-4 rounded-lg">
          <h3 className="text-sm font-medium opacity-90">投票权</h3>
          <p className="text-2xl font-bold">
            {votingPower ? formatEther(votingPower) : '0'}
          </p>
        </div>
        <div className="bg-gradient-to-r from-purple-500 to-pink-500 text-white p-4 rounded-lg">
          <h3 className="text-sm font-medium opacity-90">提案总数</h3>
          <p className="text-2xl font-bold">
            {proposalCount ? proposalCount.toString() : '0'}
          </p>
        </div>
        <div className="bg-gradient-to-r from-orange-500 to-red-500 text-white p-4 rounded-lg">
          <h3 className="text-sm font-medium opacity-90">委托状态</h3>
          <p className="text-xs font-medium">
            {delegate === address ? '自委托' : delegate ? '已委托' : '未委托'}
          </p>
          {delegate && delegate !== address && (
            <p className="text-xs opacity-90 truncate">
              {delegate.slice(0, 8)}...{delegate.slice(-6)}
            </p>
          )}
        </div>
      </div>

      {/* 治理参数 */}
      <div className="bg-gray-50 dark:bg-gray-700 p-4 rounded-lg mb-6">
        <h3 className="text-lg font-semibold mb-3 text-gray-900 dark:text-white">治理参数</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <span className="text-gray-600 dark:text-gray-300">提案门槛: </span>
            <span className="font-medium">{proposalThreshold ? formatEther(proposalThreshold) : '0'} SUSHI</span>
          </div>
          <div>
            <span className="text-gray-600 dark:text-gray-300">法定人数: </span>
            <span className="font-medium">{quorumPercentage ? quorumPercentage.toString() : '0'}%</span>
          </div>
          <div>
            <span className="text-gray-600 dark:text-gray-300">投票延迟: </span>
            <span className="font-medium">{votingDelay ? votingDelay.toString() : '0'} 块</span>
          </div>
          <div>
            <span className="text-gray-600 dark:text-gray-300">投票期间: </span>
            <span className="font-medium">{votingPeriod ? votingPeriod.toString() : '0'} 块</span>
          </div>
        </div>
      </div>

      {/* 标签页 */}
      <div className="flex space-x-1 mb-6 bg-gray-100 dark:bg-gray-700 p-1 rounded-lg">
        {[
          { id: 'proposals', label: '📋 提案列表', icon: '📋' },
          { id: 'create', label: '✍️ 创建提案', icon: '✍️' },
          { id: 'delegate', label: '🤝 委托投票', icon: '🤝' }
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              activeTab === tab.id
                ? 'bg-white dark:bg-gray-600 text-blue-600 dark:text-blue-400 shadow-sm'
                : 'text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* 提案列表 */}
      {activeTab === 'proposals' && (
        <div className="space-y-4">
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white">所有提案</h3>
          
          {proposalCount && Number(proposalCount) > 0 ? (
            // 渲染提案列表
            Array.from({ length: Number(proposalCount) }, (_, i) => (
              <ProposalCard key={i} proposalId={i + 1} onVote={handleVote} onQueue={handleQueue} onExecute={handleExecute} />
            ))
          ) : (
            <div className="text-center py-8 text-gray-500 dark:text-gray-400">
              暂无提案
            </div>
          )}
        </div>
      )}

      {/* 创建提案 */}
      {activeTab === 'create' && (
        <div className="space-y-6">
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white">创建新提案</h3>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              治理函数
            </label>
            <select
              value={proposalFunction}
              onChange={(e) => setProposalFunction(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            >
              <option value="updateSushiPerBlock">更新SUSHI每区块奖励</option>
              <option value="add">添加新的挖矿池</option>
              <option value="set">修改现有池子分配点数</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              函数参数
            </label>
            <input
              type="text"
              value={functionParams}
              onChange={(e) => setFunctionParams(e.target.value)}
              placeholder={
                proposalFunction === 'updateSushiPerBlock' ? '新的每区块SUSHI数量 (如: 1.5)' :
                proposalFunction === 'add' ? '分配点数,LP代币地址 (如: 100,0x...)' :
                '池子ID,新分配点数 (如: 0,100)'
              }
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              提案描述
            </label>
            <textarea
              value={proposalDescription}
              onChange={(e) => setProposalDescription(e.target.value)}
              placeholder="详细描述这个提案的目的和影响..."
              rows={4}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <button
            onClick={handleCreateProposal}
            disabled={isPending || !proposalDescription || !functionParams}
            className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
          >
            {isPending ? '创建中...' : '创建提案'}
          </button>
        </div>
      )}

      {/* 委托投票 */}
      {activeTab === 'delegate' && (
        <div className="space-y-6">
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white">委托投票权</h3>
          
          <div className="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
            <h4 className="font-medium text-blue-900 dark:text-blue-200 mb-2">当前委托状态</h4>
            <p className="text-sm text-blue-800 dark:text-blue-300">
              {delegate === address ? (
                '✅ 已自委托 - 您可以直接使用自己的投票权'
              ) : delegate ? (
                <>已委托给: <span className="font-mono">{delegate}</span></>
              ) : (
                '❌ 未委托 - 您需要委托后才能获得投票权'
              )}
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              委托地址
            </label>
            <input
              type="text"
              value={delegateAddress}
              onChange={(e) => setDelegateAddress(e.target.value)}
              placeholder="输入要委托的地址 (0x...)"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>

          <div className="flex space-x-4">
            <button
              onClick={handleSelfDelegate}
              disabled={isPending}
              className="flex-1 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
            >
              {isPending ? '委托中...' : '自委托'}
            </button>
            <button
              onClick={handleDelegate}
              disabled={isPending || !delegateAddress}
              className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
            >
              {isPending ? '委托中...' : '委托给他人'}
            </button>
          </div>
        </div>
      )}

      {/* 交易状态 */}
      {hash && (
        <div className="mt-6 p-4 bg-blue-100 dark:bg-blue-900 rounded-md">
          <div className="mb-2">
            <p className="text-sm font-medium text-blue-800 dark:text-blue-200 mb-1">
              交易哈希:
            </p>
            <div className="flex items-center gap-2">
              <p 
                className="text-xs text-blue-700 dark:text-blue-300 font-mono break-all cursor-pointer hover:bg-blue-200 dark:hover:bg-blue-800 p-1 rounded"
                onClick={() => copyToClipboard(hash)}
                title="点击复制"
              >
                {hash}
              </p>
            </div>
          </div>
          <p className="text-sm text-blue-600 dark:text-blue-400">
            状态: {isConfirming ? '确认中...' : isConfirmed ? '✅ 已确认' : '等待确认'}
          </p>
        </div>
      )}
    </div>
  )
}

// 提案卡片组件
function ProposalCard({ 
  proposalId, 
  onVote, 
  onQueue, 
  onExecute 
}: { 
  proposalId: number
  onVote: (id: number, support: VoteType) => void
  onQueue: (id: number) => void
  onExecute: (id: number) => void
}) {
  const { address } = useAccount()

  // 读取提案详情
  const { data: proposal } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'getProposal',
    args: [BigInt(proposalId)]
  })

  // 读取提案状态
  const { data: proposalState } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'state',
    args: [BigInt(proposalId)]
  })

  // 检查用户是否已投票
  const { data: hasVoted } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'hasVoted',
    args: [BigInt(proposalId), address],
    query: { enabled: !!address }
  })

  // 获取用户的投票
  const { data: userVote } = useReadContract({
    address: DAO_ADDRESS as `0x${string}`,
    abi: SimpleDAOABI,
    functionName: 'getVote',
    args: [BigInt(proposalId), address],
    query: { enabled: !!address && hasVoted }
  })

  if (!proposal) return null

  const [proposer, target, value, data, description, startTime, endTime, forVotes, againstVotes, abstainVotes, executed, canceled] = proposal

  const state = Number(proposalState || 0)
  const totalVotes = forVotes + againstVotes + abstainVotes
  const forPercentage = totalVotes > 0 ? Number(forVotes * 100n / totalVotes) : 0
  const againstPercentage = totalVotes > 0 ? Number(againstVotes * 100n / totalVotes) : 0

  const getStateName = (state: number) => {
    const states = ['等待中', '投票中', '已取消', '被否决', '已通过', '队列中', '已过期', '已执行']
    return states[state] || '未知'
  }

  const getStateColor = (state: number) => {
    const colors = [
      'bg-gray-100 text-gray-800',
      'bg-blue-100 text-blue-800',
      'bg-red-100 text-red-800',
      'bg-red-100 text-red-800',
      'bg-green-100 text-green-800',
      'bg-yellow-100 text-yellow-800',
      'bg-gray-100 text-gray-800',
      'bg-green-100 text-green-800'
    ]
    return colors[state] || 'bg-gray-100 text-gray-800'
  }

  const getVoteLabel = (vote: number) => {
    return ['反对', '赞成', '弃权'][vote] || '未知'
  }

  return (
    <div className="border border-gray-200 dark:border-gray-600 rounded-lg p-6 space-y-4">
      <div className="flex items-start justify-between">
        <div>
          <h4 className="text-lg font-semibold text-gray-900 dark:text-white">
            提案 #{proposalId}
          </h4>
          <p className="text-sm text-gray-600 dark:text-gray-400">
            提案人: {proposer.slice(0, 8)}...{proposer.slice(-6)}
          </p>
        </div>
        <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStateColor(state)}`}>
          {getStateName(state)}
        </span>
      </div>

      <div className="bg-gray-50 dark:bg-gray-700 p-3 rounded-md">
        <p className="text-sm text-gray-900 dark:text-white">{description}</p>
      </div>

      {/* 投票结果 */}
      <div className="space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-gray-600 dark:text-gray-400">赞成票</span>
          <span className="font-medium text-green-600">{formatEther(forVotes)} ({forPercentage.toFixed(1)}%)</span>
        </div>
        <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
          <div 
            className="bg-green-500 h-2 rounded-full transition-all duration-300"
            style={{ width: `${forPercentage}%` }}
          />
        </div>
        
        <div className="flex justify-between text-sm">
          <span className="text-gray-600 dark:text-gray-400">反对票</span>
          <span className="font-medium text-red-600">{formatEther(againstVotes)} ({againstPercentage.toFixed(1)}%)</span>
        </div>
        <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
          <div 
            className="bg-red-500 h-2 rounded-full transition-all duration-300"
            style={{ width: `${againstPercentage}%` }}
          />
        </div>
      </div>

      {/* 用户投票状态 */}
      {hasVoted && (
        <div className="bg-blue-50 dark:bg-blue-900/20 p-3 rounded-md">
          <p className="text-sm text-blue-800 dark:text-blue-200">
            您已投票: <span className="font-medium">{getVoteLabel(Number(userVote))}</span>
          </p>
        </div>
      )}

      {/* 操作按钮 */}
      <div className="flex space-x-2">
        {state === ProposalState.Active && !hasVoted && (
          <>
            <button
              onClick={() => onVote(proposalId, VoteType.For)}
              className="flex-1 px-3 py-2 bg-green-600 text-white text-sm rounded-md hover:bg-green-700 transition-colors"
            >
              赞成
            </button>
            <button
              onClick={() => onVote(proposalId, VoteType.Against)}
              className="flex-1 px-3 py-2 bg-red-600 text-white text-sm rounded-md hover:bg-red-700 transition-colors"
            >
              反对
            </button>
            <button
              onClick={() => onVote(proposalId, VoteType.Abstain)}
              className="flex-1 px-3 py-2 bg-gray-600 text-white text-sm rounded-md hover:bg-gray-700 transition-colors"
            >
              弃权
            </button>
          </>
        )}
        
        {state === ProposalState.Succeeded && (
          <button
            onClick={() => onQueue(proposalId)}
            className="flex-1 px-3 py-2 bg-yellow-600 text-white text-sm rounded-md hover:bg-yellow-700 transition-colors"
          >
            加入执行队列
          </button>
        )}
        
        {state === ProposalState.Queued && (
          <button
            onClick={() => onExecute(proposalId)}
            className="flex-1 px-3 py-2 bg-purple-600 text-white text-sm rounded-md hover:bg-purple-700 transition-colors"
          >
            执行提案
          </button>
        )}
      </div>
    </div>
  )
} 
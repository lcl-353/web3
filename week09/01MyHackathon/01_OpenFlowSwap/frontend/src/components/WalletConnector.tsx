'use client'

import { useConnect, useAccount, useDisconnect } from 'wagmi'
import { metaMask } from 'wagmi/connectors'

export function WalletConnector() {
  const { address, isConnected } = useAccount()
  const { connect, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div className="flex items-center gap-4">
        <span className="text-sm text-gray-600 dark:text-gray-300">
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </span>
        <button
          onClick={() => disconnect()}
          className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 transition-colors"
        >
          断开连接
        </button>
      </div>
    )
  }

  return (
    <button
      onClick={() => connect({ connector: metaMask() })}
      disabled={isPending}
      className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
    >
      {isPending ? '连接中...' : '连接MetaMask'}
    </button>
  )
} 
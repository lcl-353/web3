import { WagmiProviderWrapper } from '@/components/providers/WagmiProvider'
import { WalletConnect } from '@/components/WalletConnect'
import { NFTMarket } from '@/components/NFTMarket'

export default function Home() {
  return (
    <WagmiProviderWrapper>
      <div className="min-h-screen bg-gray-50">
        {/* 头部导航 */}
        <header className="bg-white shadow-sm border-b">
          <div className="max-w-6xl mx-auto px-6 py-4">
            <div className="flex justify-between items-center">
              <h1 className="text-2xl font-bold text-gray-900">NFT市场</h1>
              <WalletConnect />
            </div>
          </div>
        </header>

        {/* 主要内容 */}
        <main className="max-w-6xl mx-auto px-6 py-8">
          <NFTMarket />
        </main>
      </div>
    </WagmiProviderWrapper>
  )
}

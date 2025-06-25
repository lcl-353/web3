import Image from "next/image";
import { WalletConnector } from "../components/WalletConnector";
import { LiquidityManager } from "../components/LiquidityManager";
import { SwapManager } from "../components/SwapManager";
import { FarmingManager } from "../components/FarmingManager";
import { DAOGovernance } from "../components/DAOGovernance";

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      {/* 固定导航栏 */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200 dark:border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-4">
              <h1 className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                OpenFlow DeFi
              </h1>
              <nav className="hidden md:flex space-x-6">
                <a href="#swap" className="text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
                  交易
                </a>
                <a href="#liquidity" className="text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
                  流动性
                </a>
                <a href="#farming" className="text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
                  挖矿
                </a>
                <a href="#governance" className="text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
                  治理
                </a>
              </nav>
            </div>
            <WalletConnector />
          </div>
        </div>
      </nav>

      {/* 主要内容区域 */}
      <div className="pt-16">
        {/* Hero区域 */}
        <section className="relative py-20 px-4 text-center">
          <div className="max-w-4xl mx-auto">
            <h1 className="text-5xl md:text-6xl font-bold mb-6 bg-gradient-to-r from-blue-600 via-purple-600 to-pink-600 bg-clip-text text-transparent">
              OpenFlow DeFi Platform
            </h1>
            <p className="text-xl text-gray-600 dark:text-gray-300 mb-8 max-w-2xl mx-auto">
              全功能去中心化金融平台，集成交易、流动性挖矿、DAO治理于一体
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="#swap"
                className="px-8 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-lg shadow-lg hover:from-blue-700 hover:to-purple-700 transition-all duration-300 transform hover:scale-105"
              >
                开始交易
              </a>
              <a
                href="#liquidity"
                className="px-8 py-3 border-2 border-blue-600 text-blue-600 dark:text-blue-400 font-semibold rounded-lg hover:bg-blue-600 hover:text-white dark:hover:bg-blue-600 dark:hover:text-white transition-all duration-300"
              >
                提供流动性
              </a>
            </div>
          </div>
        </section>

        {/* 功能区域 */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-20">
          
          {/* 交易区域 */}
          <section id="swap" className="scroll-mt-20">
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
                🔄 代币交易
              </h2>
              <p className="text-lg text-gray-600 dark:text-gray-300">
                快速、安全的去中心化代币交换
              </p>
            </div>
            <SwapManager />
          </section>

          {/* 流动性管理区域 */}
          <section id="liquidity" className="scroll-mt-20">
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
                💧 流动性管理
              </h2>
              <p className="text-lg text-gray-600 dark:text-gray-300">
                添加流动性，获得交易手续费分润
              </p>
            </div>
            <LiquidityManager />
          </section>

          {/* 流动性挖矿区域 */}
          <section id="farming" className="scroll-mt-20">
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
                🚜 流动性挖矿
              </h2>
              <p className="text-lg text-gray-600 dark:text-gray-300">
                质押LP代币，挖取SUSHI奖励
              </p>
            </div>
            <FarmingManager />
          </section>

          {/* DAO治理区域 */}
          <section id="governance" className="scroll-mt-20">
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
                🏛️ DAO治理
              </h2>
              <p className="text-lg text-gray-600 dark:text-gray-300">
                参与协议治理，决定平台发展方向
              </p>
            </div>
            <DAOGovernance />
          </section>

        </div>

        {/* 页脚 */}
        <footer className="mt-20 py-12 px-4 border-t border-gray-200 dark:border-gray-700">
          <div className="max-w-7xl mx-auto text-center">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-8">
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-4">平台特性</h3>
                <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  <li>去中心化交易</li>
                  <li>自动做市商(AMM)</li>
                  <li>流动性挖矿</li>
                  <li>DAO治理</li>
                </ul>
              </div>
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-4">支持网络</h3>
                <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  <li>Ethereum Mainnet</li>
                  <li>Sepolia Testnet</li>
                  <li>Foundry Local</li>
                </ul>
              </div>
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-4">安全</h3>
                <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  <li>智能合约审计</li>
                  <li>多重签名</li>
                  <li>去中心化治理</li>
                  <li>开源代码</li>
                </ul>
              </div>
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-4">社区</h3>
                <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  <li>Discord</li>
                  <li>Twitter</li>
                  <li>GitHub</li>
                  <li>Documentation</li>
                </ul>
              </div>
            </div>
            <div className="border-t border-gray-200 dark:border-gray-700 pt-8">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                © 2024 OpenFlow DeFi Platform. 基于区块链技术构建的去中心化金融协议。
              </p>
            </div>
          </div>
        </footer>
      </div>
    </div>
  );
}

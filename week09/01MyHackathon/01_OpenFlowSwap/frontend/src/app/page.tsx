import Image from "next/image";
import { WalletConnector } from "../components/WalletConnector";

export default function Home() {
  return (
    <div className="min-h-screen relative">
      {/* 钱包连接按钮 - 右上角 */}
      <div className="absolute top-4 right-4 z-10">
        <WalletConnector />
      </div>
      
      {/* 主要内容 */}
      <div className="grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20 font-[family-name:var(--font-geist-sans)]">
        <main className="flex flex-col gap-[32px] row-start-2 items-center sm:items-start">
          <div className="text-center">
            <h1 className="text-4xl font-bold mb-4 bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              OpenFlow DeFi Platform
            </h1>
            <p className="text-lg text-gray-600 dark:text-gray-300">
              去中心化交易 · 流动性挖矿 · 治理投票
            </p>
          </div>

          <Image
            className="dark:invert"
            src="/next.svg"
            alt="OpenFlow Logo"
            width={180}
            height={38}
            priority
          />
          
          <ol className="list-inside list-decimal text-sm/6 text-center sm:text-left font-[family-name:var(--font-geist-mono)]">
            <li className="mb-2 tracking-[-.01em]">
              连接您的MetaMask钱包开始使用{" "}
              <code className="bg-black/[.05] dark:bg-white/[.06] px-1 py-0.5 rounded font-[family-name:var(--font-geist-mono)] font-semibold">
                OpenFlow DeFi
              </code>
              平台。
            </li>
            <li className="tracking-[-.01em]">
              体验去中心化交易、流动性挖矿和DAO治理功能。
            </li>
          </ol>

          <div className="flex gap-4 items-center flex-col sm:flex-row">
            <a
              className="rounded-full border border-solid border-transparent transition-colors flex items-center justify-center bg-foreground text-background gap-2 hover:bg-[#383838] dark:hover:bg-[#ccc] font-medium text-sm sm:text-base h-10 sm:h-12 px-4 sm:px-5 sm:w-auto"
              href="#"
              rel="noopener noreferrer"
            >
              开始交易
            </a>
            <a
              className="rounded-full border border-solid border-black/[.08] dark:border-white/[.145] transition-colors flex items-center justify-center hover:bg-[#f2f2f2] dark:hover:bg-[#1a1a1a] hover:border-transparent font-medium text-sm sm:text-base h-10 sm:h-12 px-4 sm:px-5 w-full sm:w-auto md:w-[158px]"
              href="#"
              rel="noopener noreferrer"
            >
              了解更多
            </a>
          </div>
        </main>
        <footer className="row-start-3 flex gap-[24px] flex-wrap items-center justify-center">
          <a
            className="flex items-center gap-2 hover:underline hover:underline-offset-4"
            href="#"
            rel="noopener noreferrer"
          >
            <Image
              aria-hidden
              src="/file.svg"
              alt="File icon"
              width={16}
              height={16}
            />
            教程
          </a>
          <a
            className="flex items-center gap-2 hover:underline hover:underline-offset-4"
            href="#"
            rel="noopener noreferrer"
          >
            <Image
              aria-hidden
              src="/window.svg"
              alt="Window icon"
              width={16}
              height={16}
            />
            示例
          </a>
          <a
            className="flex items-center gap-2 hover:underline hover:underline-offset-4"
            href="#"
            rel="noopener noreferrer"
          >
            <Image
              aria-hidden
              src="/globe.svg"
              alt="Globe icon"
              width={16}
              height={16}
            />
            OpenFlow DeFi →
          </a>
        </footer>
      </div>
    </div>
  );
}

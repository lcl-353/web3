import { createPublicClient, createWalletClient, http, parseEther, formatEther, getAddress } from 'viem';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { program } from 'commander';
import * as dotenv from 'dotenv';
import { readFileSync, writeFileSync, existsSync } from 'fs';

dotenv.config();

// ERC20 代币的 ABI
const ERC20_ABI = [
  {
    "constant": true,
    "inputs": [{ "name": "_owner", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "balance", "type": "uint256" }],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      { "name": "_to", "type": "address" },
      { "name": "_value", "type": "uint256" }
    ],
    "name": "transfer",
    "outputs": [{ "name": "", "type": "bool" }],
    "type": "function"
  }
];

// 创建客户端实例
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(process.env.SEPOLIA_RPC_URL)
});

const WALLET_FILE = 'wallet.json';

// 保存钱包信息
function saveWallet(privateKey: string) {
  writeFileSync(WALLET_FILE, JSON.stringify({ privateKey }));
  console.log('Wallet saved to wallet.json');
}

// 加载钱包信息
function loadWallet(): string | null {
  try {
    if (existsSync(WALLET_FILE)) {
      const data = readFileSync(WALLET_FILE, 'utf8');
      return JSON.parse(data).privateKey;
    }
  } catch (error) {
    console.error('Error loading wallet:', error);
  }
  return null;
}

// 生成新钱包
async function generateWallet() {
  const privateKey = generatePrivateKey();
  const account = privateKeyToAccount(privateKey);
  console.log('Generated new account:');
  console.log('Address:', getAddress(account.address));
  console.log('Private Key:', privateKey);
  saveWallet(privateKey);
}

// 查询 ETH 余额
async function getBalance(address: string) {
  const hexAddress = getAddress(address); // 确保地址格式正确
  const balance = await publicClient.getBalance({ address: hexAddress });
  console.log('ETH Balance:', formatEther(balance), 'ETH');privateKeyToAccount
}

// 查询 ERC20 余额
async function getTokenBalance(address: string) {
  const hexAddress = getAddress(address); // 确保地址格式正确
  const balance = await publicClient.readContract({
    address: process.env.ERC20_CONTRACT_ADDRESS as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [hexAddress as `0x${string}`]
  }) as bigint;  // 明确指定返回类型为 bigint
  console.log('Token Balance:', formatEther(balance), 'Tokens');
}

// 发送 ERC20 代币
async function sendToken(to: string, amount: string) {
  const privateKey = loadWallet();
  if (!privateKey) {
    console.error('No wallet found. Generate one first.');
    return;
  }

  const account = privateKeyToAccount(privateKey as `0x${string}`);
  const walletClient = createWalletClient({
    account,
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL)
  });

  try {
    const hexToAddress = getAddress(to); // 确保接收地址格式正确
    const { request } = await publicClient.simulateContract({
      account,
      address: process.env.ERC20_CONTRACT_ADDRESS as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'transfer',
      args: [hexToAddress, parseEther(amount)]
    });

    const hash = await walletClient.writeContract(request);
    console.log('Transaction hash:', hash);

    // 等待交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log('Transaction confirmed in block:', receipt.blockNumber);
  } catch (error) {
    console.error('Error sending tokens:', error);
  }
}

// 设置命令行参数
program
  .version('1.0.0')
  .description('CLI Wallet using Viem');

program
  .command('generate')
  .description('Generate a new wallet')
  .action(generateWallet);

program
  .command('balance <address>')
  .description('Get ETH balance')
  .action(getBalance);

program
  .command('token-balance <address>')
  .description('Get ERC20 token balance')
  .action(getTokenBalance);

program
  .command('send-token <to> <amount>')
  .description('Send ERC20 tokens')
  .action(sendToken);

program.parse(process.argv);

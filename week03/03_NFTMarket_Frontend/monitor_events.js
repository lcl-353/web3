import { createPublicClient, http, parseAbi, formatEther } from 'viem';
import { foundry } from 'viem/chains';
import fs from 'fs';

// Load contract ABI from the contract itself
const abi = parseAbi([
  'event Listed(uint256 indexed tokenId, address indexed seller, uint256 price)',
  'event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price)',
  'event Print(uint256 indexed tokenId, address indexed buyer, uint256 price)'
]);

// Update these values with your network and contract details
const PROVIDER_URL = 'http://localhost:8545'; // Use your RPC endpoint
const NFT_MARKET_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'; // Update with your deployed contract address

async function monitorNFTMarketEvents() {
  // Create a public client
  const client = createPublicClient({
    chain: foundry,
    transport: http(PROVIDER_URL),
    pollingInterval: 1_000 // Poll every 1 second
  });
  
  console.log('Starting to monitor NFT market events...');

  // Watch for Listed events
  const unwatch1 = client.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi,
    eventName: 'Listed',
    onLogs: (logs) => {
      for (const log of logs) {
        const { args, transactionHash } = log;
        console.log('\n--- NFT LISTED ---');
        console.log(`Token ID: ${args.tokenId.toString()}`);
        console.log(`Seller: ${args.seller}`);
        console.log(`Price: ${formatEther(args.price)} ETH`);
        console.log(`Transaction Hash: ${transactionHash}`);
        console.log('------------------');
      }
    },
  });

  // Watch for Bought events
  const unwatch2 = client.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi,
    eventName: 'Bought',
    onLogs: (logs) => {
      for (const log of logs) {
        const { args, transactionHash } = log;
        console.log('\n--- NFT BOUGHT ---');
        console.log(`Token ID: ${args.tokenId.toString()}`);
        console.log(`Buyer: ${args.buyer}`);
        console.log(`Price: ${formatEther(args.price)} ETH`);
        console.log(`Transaction Hash: ${transactionHash}`);
        console.log('------------------');
      }
    },
  });

  // Watch for Print events (debug)
  const unwatch3 = client.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi,
    eventName: 'Print',
    onLogs: (logs) => {
      for (const log of logs) {
        const { args, transactionHash } = log;
        console.log('\n--- TOKEN RECEIVED DEBUG ---');
        console.log(`Token ID: ${args.tokenId.toString()}`);
        console.log(`Buyer: ${args.buyer}`);
        console.log(`Amount: ${formatEther(args.price)} ETH`);
        console.log(`Transaction Hash: ${transactionHash}`);
        console.log('---------------------------');
      }
    },
  });

  console.log('Event monitoring active. Press Ctrl+C to exit.');
  
  // Setup cleanup for unwatch on exit
  process.on('SIGINT', () => {
    console.log('Stopping event monitoring...');
    unwatch1();
    unwatch2();
    unwatch3();
    process.exit(0);
  });
}

// Run the monitoring function
monitorNFTMarketEvents().catch(error => {
  console.error('Error in monitoring script:', error);
  process.exit(1);
}); 
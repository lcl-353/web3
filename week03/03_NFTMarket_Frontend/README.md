# NFT Market with Event Monitoring

This project contains an NFT marketplace contract and a monitoring script to track listing and purchase events.

## Contract Events

The NFTMarket contract emits the following events that can be monitored:

1. `Listed(uint256 indexed tokenId, address indexed seller, uint256 price)` - Emitted when an NFT is listed for sale
2. `Bought(uint256 indexed tokenId, address indexed buyer, uint256 price)` - Emitted when an NFT is purchased
3. `Print(uint256 indexed tokenId, address indexed buyer, uint256 price)` - Debug event emitted during tokenReceived processing

## Setting Up Event Monitoring

### Prerequisites

- Node.js (v16 or newer)
- Access to an Ethereum node or service (Infura, Alchemy, or local node)
- Deployed NFTMarket contract

### Installation

```bash
# Install required packages
npm install viem
```

### Configuration

Edit the `monitor_events.js` file to set:

1. `PROVIDER_URL` - Your Ethereum node URL
2. `NFT_MARKET_ADDRESS` - The address of your deployed NFTMarket contract
3. Update the chain configuration if not using mainnet (in the `createPublicClient` call)

Make sure the ABI path is correct:
```javascript
const NFTMarketJSON = JSON.parse(fs.readFileSync('./artifacts/contracts/NFT_Market_and_ERC20.sol/NFTMarket.json', 'utf8'));
```

### Running the Monitor

```bash
# If you're using ES modules
node --experimental-json-modules monitor_events.js
# Or, add "type": "module" to your package.json
```

The script will start monitoring and display information about NFT listings and purchases in real-time:

- When an NFT is listed, it will show the token ID, seller address, and price
- When an NFT is purchased, it will show the token ID, buyer address, and price

## Example Output

When an NFT is listed:
```
--- NFT LISTED ---
Token ID: 5
Seller: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
Price: 0.1 ETH
Transaction Hash: 0x123...
------------------
```

When an NFT is purchased:
```
--- NFT BOUGHT ---
Token ID: 5
Buyer: 0xdD2FD4581271e230360230F9337D5c0430Bf44C0
Price: 0.1 ETH
Transaction Hash: 0x456...
------------------
```

## Troubleshooting

- If you're not seeing events, check that your contract address and provider URL are correct
- Ensure your node has WebSocket support enabled for real-time events (viem supports both HTTP and WebSocket)
- To view historical events, you can use `client.getContractEvents` instead of `watchContractEvent`
- If you encounter import errors, make sure your environment supports ES modules

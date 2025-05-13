# TokenBank Frontend

This is a React-based frontend for interacting with the TokenBank smart contract, using viem for Ethereum interactions.

## Features

- Connect to MetaMask or other Ethereum wallets
- View your ERC20 token balance
- Deposit tokens to the TokenBank contract
- View your deposited balance in the bank
- Withdraw tokens from the TokenBank

## Technologies Used

- React for the frontend UI
- viem for Ethereum interactions
- Web3Modal for wallet connection

## Before Running

Before using this frontend, you need to:

1. Deploy the MyToken and TokenBank contracts
2. Update the contract addresses in `src/App.js`:
   ```javascript
   const TOKEN_BANK_ADDRESS = "YOUR_DEPLOYED_TOKEN_BANK_ADDRESS";
   const TOKEN_ADDRESS = "YOUR_DEPLOYED_TOKEN_ADDRESS";
   ```

## Setup

Install dependencies:

```bash
npm install
```

Start the development server:

```bash
npm start
```

The application will be available at http://localhost:3000

## Usage

1. Connect your wallet by clicking the "Connect Wallet" button
2. Enter the amount of tokens you want to deposit or withdraw
3. Click the "Deposit" or "Withdraw" button
4. Confirm the transaction in your wallet

## Contract Integration

This frontend interacts with two smart contracts:
- An ERC20 token contract
- The TokenBank contract that allows users to deposit and withdraw tokens

Both contracts must be deployed to the blockchain before using this frontend. 
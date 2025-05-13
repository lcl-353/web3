import React, { useState, useEffect } from 'react';
import { createPublicClient, createWalletClient, http, parseEther, formatEther, custom } from 'viem';
import { foundry } from 'viem/chains';
import TokenBankABI from './abis/TokenBank.json';
import ERC20ABI from './abis/ERC20.json';
import './App.css';

// Contract addresses (update these with your deployed contract addresses)
const TOKEN_BANK_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
const TOKEN_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

function App() {
  const [account, setAccount] = useState('');
  const [tokenBalance, setTokenBalance] = useState('0');
  const [bankBalance, setBankBalance] = useState('0');
  const [amount, setAmount] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [publicClient, setPublicClient] = useState(null);
  const [walletClient, setWalletClient] = useState(null);

  // 简化的钱包连接函数
  const connectWallet = async () => {
    try {
      console.log("开始连接钱包...");
      
      // 最简单的方法，直接使用 window.ethereum
      if (typeof window.ethereum !== 'undefined') {
        console.log("找到以太坊提供者");
        
        // 基础连接 - 最小化代码路径
        const accounts = await window.ethereum.request({ 
          method: 'eth_accounts' 
        });
        
        if (accounts.length === 0) {
          console.log("无已连接账户，请求连接");
          // 尝试最简单的连接方式
          await window.ethereum.request({ 
            method: 'eth_requestAccounts' 
          });
        }
        
        // 重新获取账户
        const finalAccounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (finalAccounts.length === 0) {
          throw new Error("未能获取账户");
        }
        
        const account = finalAccounts[0];
        console.log("成功连接到账户:", account);
        
        // 简化的客户端创建
        const publicClient = createPublicClient({
          chain: foundry,
          transport: http(),
        });
        
        const walletClient = createWalletClient({
          chain: foundry,
          transport: custom(window.ethereum),
        });
        
        setAccount(account);
        setPublicClient(publicClient);
        setWalletClient(walletClient);
        setIsConnected(true);
  
        await updateBalances(account, publicClient);
      } else {
        alert("未检测到以太坊钱包! 请安装 MetaMask 或其他钱包扩展。");
      }
    } catch (error) {
      console.error("连接钱包错误:", error);
      alert("连接失败: " + (error.message || "未知错误"));
    }
  };

  const updateBalances = async (address, client) => {
    try {
      if (!client || !address) return;
      
      console.log("开始查询余额...");
      console.log("地址:", address);
      console.log("代币地址:", TOKEN_ADDRESS);
      console.log("银行地址:", TOKEN_BANK_ADDRESS);

      // 在前端代码中添加检查
      try {
        const code = await client.getBytecode({ address: TOKEN_ADDRESS });
        console.log("合约字节码:", code ? "存在" : "不存在或为空");
      } catch (error) {
        console.error("检查合约代码失败:", error);
      }
      
      // 使用 ERC20ABI 和 TokenBankABI 直接作为 abi 参数，不使用 parseAbi
      try {
        // 获取代币余额
        const tokenBalanceResult = await client.readContract({
          address: TOKEN_ADDRESS,
          abi: ERC20ABI,  // 直接使用导入的 ABI
          functionName: 'balanceOf',
          args: [address],
        });
        
        console.log("查询代币余额成功:", tokenBalanceResult);
        setTokenBalance(formatEther(tokenBalanceResult));
      } catch (tokenError) {
        console.error("查询代币余额失败:", tokenError);
      }
      
      try {
        // 获取银行余额
        const bankBalanceResult = await client.readContract({
          address: TOKEN_BANK_ADDRESS,
          abi: TokenBankABI,  // 直接使用导入的 ABI
          functionName: 'balances',
          args: [address],
        });
        
        console.log("查询银行余额成功:", bankBalanceResult);
        setBankBalance(formatEther(bankBalanceResult));
      } catch (bankError) {
        console.error("查询银行余额失败:", bankError);
      }
    } catch (error) {
      console.error("Error updating balances:", error);
    }
  };

  // Function to deposit tokens to bank
  const depositTokens = async () => {
    if (!amount || !walletClient || !publicClient) return;

    try {
      const amountInWei = parseEther(amount);
      
      // First approve the token transfer
      const approveHash = await walletClient.writeContract({
        address: TOKEN_ADDRESS,
        abi: ERC20ABI,  // 直接使用导入的 ABI
        functionName: 'approve',
        args: [TOKEN_BANK_ADDRESS, amountInWei],
        account,
      });
      
      // Wait for transaction confirmation
      await publicClient.waitForTransactionReceipt({ hash: approveHash });
      
      // Then deposit
      const depositHash = await walletClient.writeContract({
        address: TOKEN_BANK_ADDRESS,
        abi: TokenBankABI,  // 直接使用导入的 ABI
        functionName: 'deposit',
        args: [amountInWei],
        account,
      });
      
      // Wait for transaction confirmation
      await publicClient.waitForTransactionReceipt({ hash: depositHash });
      
      // Update balances
      await updateBalances(account, publicClient);
      setAmount('');
      
      alert('Deposit successful!');
    } catch (error) {
      console.error("Error depositing tokens:", error);
      alert('Error depositing tokens. Check console for details.');
    }
  };

  // Function to withdraw tokens from bank
  const withdrawTokens = async () => {
    if (!amount || !walletClient || !publicClient) return;

    try {
      const amountInWei = parseEther(amount);
      
      const withdrawHash = await walletClient.writeContract({
        address: TOKEN_BANK_ADDRESS,
        abi: TokenBankABI,  // 直接使用导入的 ABI
        functionName: 'withdraw',
        args: [amountInWei],
        account,
      });
      
      // Wait for transaction confirmation
      await publicClient.waitForTransactionReceipt({ hash: withdrawHash });
      
      // Update balances
      await updateBalances(account, publicClient);
      setAmount('');
      
      alert('Withdrawal successful!');
    } catch (error) {
      console.error("Error withdrawing tokens:", error);
      alert('Error withdrawing tokens. Check console for details.');
    }
  };

  useEffect(() => {
    if (isConnected && publicClient) {
      updateBalances(account, publicClient);
    }
  }, [isConnected, account, publicClient]);

  return (
    <div className="App">
      <header className="App-header">
        <h1>Token Bank Interface</h1>
        
        {!isConnected ? (
          <button className="connect-button" onClick={connectWallet}>Connect Wallet</button>
        ) : (
          <div className="bank-container">
            <div className="account-info">
              <p>Connected Account: {account.slice(0, 6)}...{account.slice(-4)}</p>
              <div className="balances">
                <div className="balance-card">
                  <h3>Token Balance</h3>
                  <p>{parseFloat(tokenBalance).toFixed(4)} MTK</p>
                </div>
                <div className="balance-card">
                  <h3>Bank Balance</h3>
                  <p>{parseFloat(bankBalance).toFixed(4)} MTK</p>
                </div>
              </div>
            </div>
            
            <div className="actions">
              <div className="input-group">
                <input
                  type="number"
                  placeholder="Amount"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
              </div>
              
              <div className="button-group">
                <button onClick={depositTokens} disabled={!amount}>Deposit</button>
                <button onClick={withdrawTokens} disabled={!amount}>Withdraw</button>
              </div>
            </div>
          </div>
        )}
      </header>
    </div>
  );
}

export default App; 
import React, { useState, useEffect } from 'react';
import { createPublicClient, createWalletClient, http, parseEther, formatEther, custom } from 'viem';
import { foundry } from 'viem/chains';
import TokenBankABI from './abis/TokenBank.json';
import ERC20ABI from './abis/ERC20.json';
import './App.css';

// Contract addresses (update these with your deployed contract addresses)
const TOKEN_BANK_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const TOKEN_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

function App() {
  const [account, setAccount] = useState('');
  const [tokenBalance, setTokenBalance] = useState('0');
  const [bankBalance, setBankBalance] = useState('0');
  const [amount, setAmount] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [publicClient, setPublicClient] = useState(null);
  const [walletClient, setWalletClient] = useState(null);
  const [v, setV] = useState('');
  const [s, setS] = useState('');
  const [r, setR] = useState('');
  const [deadline, setDeadLine] = useState('');

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

  // 获取账户余额与在银行的余额
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
        // 获取账户代币余额
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
        // 获取账户在银行Token余额
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

  const permitSign = async () => {
  if (!amount || !walletClient || !publicClient || !account) return;

  try {
    const amountInWei = parseEther(amount);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 
    setDeadLine(deadline);

    // 构造 EIP-712 域信息
    const domain = {
      name: 'TestToken',        // 代币名称（需与代币合约一致）
      version: '1',
      chainId: foundry.id,   // 使用当前链ID
      verifyingContract: TOKEN_ADDRESS
    };

    // 构造签名类型和消息
    const types = {
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
      ]
    };

    // 获取当前 nonce（需确保代币合约实现 nonces 函数）
    const nonce = await publicClient.readContract({
      address: TOKEN_ADDRESS,
      abi: ERC20ABI,
      functionName: 'nonces',
      args: [account]
    });

    // 构造签名消息
    const message = {
      owner: account,
      spender: TOKEN_BANK_ADDRESS,
      value: amountInWei,
      nonce: nonce,
      deadline: deadline
    };

    // 请求用户签名
    const signature = await walletClient.signTypedData({
      account,
      domain,
      types,
      primaryType: 'Permit',
      message
    });

    setR(signature.slice(0, 66)); // 提取前32字节r
    setS("0x" + signature.slice(66, 130)); // 提取32字节s
    setV(parseInt(signature.slice(130, 132), 16)); // 转换v为十进制
    alert('Permit Signature Successful! Now you can call permitDeposit.');
    setAmount('');
  } catch (error) {
    console.error("Permit Sign Error:", error);
    alert(`Error: ${error.shortMessage || error.message}`);
  }
};

  // 在组件内添加此函数
const permitDeposit = async () => {
  if (!amount || !walletClient || !publicClient || !account) return;

  try {
    const amountInWei = parseEther(amount);
    // const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时有效期

    // // 构造 EIP-712 域信息
    // const domain = {
    //   name: 'TestToken',        // 代币名称（需与代币合约一致）
    //   version: '1',
    //   chainId: foundry.id,   // 使用当前链ID
    //   verifyingContract: TOKEN_ADDRESS
    // };

    // // 构造签名类型和消息
    // const types = {
    //   Permit: [
    //     { name: 'owner', type: 'address' },
    //     { name: 'spender', type: 'address' },
    //     { name: 'value', type: 'uint256' },
    //     { name: 'nonce', type: 'uint256' },
    //     { name: 'deadline', type: 'uint256' }
    //   ]
    // };

    // // 获取当前 nonce（需确保代币合约实现 nonces 函数）
    // const nonce = await publicClient.readContract({
    //   address: TOKEN_ADDRESS,
    //   abi: ERC20ABI,
    //   functionName: 'nonces',
    //   args: [account]
    // });

    // // 构造签名消息
    // const message = {
    //   owner: account,
    //   spender: TOKEN_BANK_ADDRESS,
    //   value: amountInWei,
    //   nonce: nonce,
    //   deadline: deadline
    // };

    // // 请求用户签名
    // const signature = await walletClient.signTypedData({
    //   account,
    //   domain,
    //   types,
    //   primaryType: 'Permit',
    //   message
    // });

    // const r = signature.slice(0, 66); // 提取前32字节r
    // const s = "0x" + signature.slice(66, 130); // 提取32字节s
    // const v = parseInt(signature.slice(130, 132), 16); // 转换v为十进制

    // 调用 permitDeposit
    const txHash = await walletClient.writeContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TokenBankABI,
      functionName: 'permitDeposit',
      args: [
        account, 
        amountInWei, 
        deadline, 
        v,
        r,
        s
      ],
      account
    });

    // 等待交易确认
    await publicClient.waitForTransactionReceipt({ hash: txHash });
    await updateBalances(account, publicClient);
    setAmount('');
    alert('Permit Deposit Successful!');
  } catch (error) {
    console.error("Permit Deposit Error:", error);
    alert(`Error: ${error.shortMessage || error.message}`);
  }
};

  useEffect(() => {
    if (isConnected && publicClient) {
      updateBalances(account, publicClient);
    }
  }, [isConnected, account, publicClient]);

  // 查询并打印chainId
  useEffect(() => {
    const checkChainId = async () => {
      try {
        console.log('=== Chain ID 检查 ===');
        
        // 方法1: 使用window.ethereum直接查询
        if (typeof window.ethereum !== 'undefined') {
          const chainId = await window.ethereum.request({ method: 'eth_chainId' });
          console.log('当前网络 Chain ID (hex):', chainId);
          console.log('当前网络 Chain ID (decimal):', parseInt(chainId, 16));
        }
        
        // 方法2: 如果有publicClient，使用viem查询
        if (publicClient) {
          const viemChainId = await publicClient.getChainId();
          console.log('Viem 查询的 Chain ID:', viemChainId);
        }
        
        // 打印预期的chainId
        console.log('预期的 Foundry Chain ID:', foundry.id);
        console.log('==================');
        
      } catch (error) {
        console.error('查询Chain ID失败:', error);
      }
    };

    // 页面加载时立即检查
    checkChainId();
    
    // 监听网络变化
    if (typeof window.ethereum !== 'undefined') {
      const handleChainChanged = (chainId) => {
        console.log('=== 网络已切换 ===');
        console.log('新的 Chain ID (hex):', chainId);
        console.log('新的 Chain ID (decimal):', parseInt(chainId, 16));
        console.log('================');
        
        // 可选：网络切换后重新连接或更新状态
        if (isConnected) {
          console.log('检测到网络切换，建议重新连接钱包');
        }
      };
      
      window.ethereum.on('chainChanged', handleChainChanged);
      
      // 清理事件监听器
      return () => {
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      };
    }
  }, [publicClient, isConnected]); // 依赖publicClient和isConnected状态

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
                <button onClick={permitSign} disabled={!amount}>Permit Sign</button>
                <button onClick={permitDeposit} disabled={!amount}>Permit Deposit</button>
                
              </div>
            </div>
          </div>
        )}
      </header>
    </div>
  );
}

export default App; 
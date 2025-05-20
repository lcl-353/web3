import { createPublicClient, http } from 'viem';
import { foundry } from 'viem/chains';

// 修改为你的RPC和合约地址
const rpcUrl = 'http://localhost:8545'; // 或者你的测试链RPC
const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// esRNT合约结构体定义
// struct LockInfo{
//     address user;
//     uint64 startTime;
//     uint256 amount;
// }

async function main() {
  const client = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  });

  // _locks数组的slot，假设为0（通常第一个声明的私有变量）
  const arraySlot = 0n;

  // 先读取数组长度
  const lengthHex = await client.getStorageAt({
    address: contractAddress,
    slot: arraySlot,
  });
  const length = BigInt(lengthHex);
  console.log(`_locks.length = ${length}`);

  // 计算数组元素的起始slot
  // 动态数组的元素起始slot = keccak256(slot)
  const { keccak256, pad } = await import('viem/utils');
  const baseSlot = keccak256(pad(arraySlot, { size: 32 }));

  for (let i = 0n; i < length; i++) {
    // LockInfo: user+startTime(1 slot), amount(1 slot)
    const slot1 = BigInt(baseSlot) + i * 2n;
    const slot2 = slot1 + 1n;

    const slot1Hex = await client.getStorageAt({
      address: contractAddress,
      slot: slot1,
    });
    const slot2Hex = await client.getStorageAt({
      address: contractAddress,
      slot: slot2,
    });

    // slot1: [0..19] user, [20..27] startTime (uint64, 8 bytes)
    const user = `0x${slot1Hex.slice(26, 66)}`; // 32 bytes hex, address在低20字节
    const startTime = BigInt('0x' + slot1Hex.slice(10, 26)); // 8字节uint64, 在address前面
    const amount = BigInt(slot2Hex);
    console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
  }
}

main().catch(console.error);

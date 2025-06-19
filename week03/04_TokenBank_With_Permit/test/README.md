# TokenBank_SupportPermit 合约测试

本目录包含了 `TokenBank_SupportPermit` 合约的完整测试套件，测试覆盖了传统存款、EIP-2612 Permit 存款和 Permit2 存款功能。

## 文件结构

```
test/
├── TokenBank.t.sol           # 原有的基础功能测试
├── TokenBankPermit2.t.sol    # 新增的 Permit2 功能测试
├── runTest.sh               # 测试运行脚本
└── README.md               # 本说明文件
```

## 测试内容

### TokenBankPermit2.t.sol

此测试文件专门测试新增的 `depositWithPermit2()` 功能，包括：

#### ✅ 核心功能测试
- **testDepositWithPermit2()** - 测试基本的 Permit2 存款功能
- **testDepositWithPermit2MultipleDeposits()** - 测试多次 Permit2 存款

#### ⚠️ 边界条件测试
- **testDepositWithPermit2ZeroAmount()** - 测试零金额存款（应失败）
- **testDepositWithPermit2ExpiredDeadline()** - 测试过期截止时间（应失败）

#### 🛡️ 安全性测试
- **testDepositWithPermit2NonceReuse()** - 测试 nonce 重用攻击防护
- **testDepositWithPermit2InvalidSignature()** - 测试无效签名防护

#### 🔄 兼容性测试
- **testBasicDeposit()** - 确保基础存款功能正常
- **testWithdraw()** - 确保提取功能正常
- **testPermitDeposit()** - 确保 EIP-2612 存款功能正常

## 运行测试

### 方法 1: 使用测试脚本 (推荐)

```bash
cd /home/linchunle/Upchain_Frontend/Upchain/web3/week03/04_TokenBank_With_Permit
./test/runTest.sh
```

### 方法 2: 手动运行

```bash
cd /home/linchunle/Upchain_Frontend/Upchain/web3/week03/04_TokenBank_With_Permit

# 编译合约
forge build

# 运行所有测试
forge test -vv

# 运行特定测试合约
forge test --match-contract TokenBankPermit2Test -vv

# 运行特定测试函数
forge test --match-test testDepositWithPermit2 -vv

# 生成测试覆盖率报告
forge coverage
```

## Mock Permit2 合约

测试中使用了 `MockPermit2` 合约来模拟真实的 Permit2 合约行为：

- **签名验证**: 完整的 EIP-712 签名验证流程
- **Nonce 管理**: 防重放攻击的 nonce bitmap 机制
- **时间检查**: 截止时间验证
- **转账执行**: 实际的代币转账操作

## 测试覆盖的场景

### 正常流程
1. 用户创建 Permit2 签名
2. 调用 `depositWithPermit2()` 方法
3. 合约验证签名并执行转账
4. 更新用户存款余额

### 异常处理
1. **无效签名** - 使用错误私钥签名
2. **过期截止时间** - 超过签名有效期
3. **重放攻击** - 重复使用相同 nonce
4. **零金额** - 尝试存入零代币

### 安全机制
1. **签名验证** - 确保只有代币持有者可以授权
2. **Nonce 防重放** - 防止签名被多次使用
3. **时间限制** - 防止过期签名被使用
4. **金额验证** - 确保存款金额有效

## 注意事项

⚠️ **重要**: 测试中的 `MockPermit2` 合约仅用于测试环境，在生产环境中应使用官方部署的 Permit2 合约：
- 主网地址: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- 测试网地址: 同主网地址

## 预期结果

所有测试应该通过，预期输出类似：

```
Running 8 tests for test/TokenBankPermit2.t.sol:TokenBankPermit2Test
[PASS] testBasicDeposit() (gas: 85419)
[PASS] testDepositWithPermit2() (gas: 146523)
[PASS] testDepositWithPermit2ExpiredDeadline() (gas: 23456)
[PASS] testDepositWithPermit2InvalidSignature() (gas: 25789)
[PASS] testDepositWithPermit2MultipleDeposits() (gas: 234567)
[PASS] testDepositWithPermit2NonceReuse() (gas: 189123)
[PASS] testDepositWithPermit2ZeroAmount() (gas: 12345)
[PASS] testWithdraw() (gas: 156789)
```

## 故障排除

如果测试失败，请检查：

1. **编译错误**: 确保所有依赖都已正确安装
2. **签名错误**: 检查 EIP-712 签名格式是否正确
3. **Nonce 管理**: 确保每次测试使用不同的 nonce
4. **时间设置**: 确保截止时间设置正确 
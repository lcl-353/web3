#!/bin/bash

# Foundry 测试脚本 - TokenBank_SupportPermit 合约测试

echo "=== TokenBank_SupportPermit 合约测试 ==="
echo ""

# 检查是否安装了 foundry
if ! command -v forge &> /dev/null; then
    echo "❌ 错误: 未找到 forge 命令，请安装 Foundry"
    echo "安装命令: curl -L https://foundry.paradigm.xyz | bash"
    exit 1
fi

echo "🔧 编译合约..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"
echo ""

echo "🧪 运行测试..."
echo ""

# 运行原有的测试
echo "1️⃣ 运行基础功能测试:"
forge test --match-contract TokenBankTest -vv

echo ""
echo "2️⃣ 运行 Permit2 功能测试:"
forge test --match-contract TokenBankPermit2Test -vv

echo ""
echo "3️⃣ 运行所有测试:"
forge test -vv

echo ""
echo "📊 生成测试覆盖率报告:"
forge coverage

echo ""
echo "✅ 测试完成!" 
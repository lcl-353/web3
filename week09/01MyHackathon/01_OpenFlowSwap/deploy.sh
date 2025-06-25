#!/bin/bash

# DeFi协议部署和交互脚本
# 使用方法: ./deploy.sh [选项]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
RPC_URL="http://localhost:8545"
CHAIN_ID=31337

echo -e "${BLUE}🚀 DeFi协议部署脚本${NC}"
echo -e "${BLUE}==================${NC}"

# 检查Foundry是否安装
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry未安装，请先安装Foundry${NC}"
    echo "安装命令: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# 检查anvil是否运行
check_anvil() {
    if ! curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        $RPC_URL > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Anvil未运行，正在启动...${NC}"
        echo "请在新终端中运行: anvil"
        echo "等待anvil启动后按任意键继续..."
        read -n 1 -s
    else
        echo -e "${GREEN}✅ Anvil正在运行${NC}"
    fi
}

# 编译合约
compile_contracts() {
    echo -e "${BLUE}📦 编译合约...${NC}"
    forge build --via-ir
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 合约编译成功${NC}"
    else
        echo -e "${RED}❌ 合约编译失败${NC}"
        exit 1
    fi
}

# 部署合约
deploy_contracts() {
    echo -e "${BLUE}🚀 部署合约到Foundry网络...${NC}"
    forge script script/DeployToFoundry.s.sol \
        --rpc-url $RPC_URL \
        --broadcast \
        --via-ir
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 合约部署成功${NC}"
        echo -e "${YELLOW}�� 部署信息已保存到 broadcast/ 目录${NC}"
    else
        echo -e "${RED}❌ 合约部署失败${NC}"
        exit 1
    fi
}

# 运行测试
run_tests() {
    echo -e "${BLUE}🧪 运行DeFi流程测试...${NC}"
    forge test --match-contract SimplifiedDeFiFlowTest --via-ir -v
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 所有测试通过${NC}"
    else
        echo -e "${RED}❌ 测试失败${NC}"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  help     显示此帮助信息"
    echo "  compile  仅编译合约"
    echo "  deploy   编译并部署合约"
    echo "  test     运行测试"
    echo "  all      执行完整流程（编译+部署+测试）"
    echo ""
    echo "示例:"
    echo "  $0 all      # 执行完整流程"
    echo "  $0 deploy   # 仅部署"
    echo "  $0 test     # 仅测试"
}

# 显示部署后的信息
show_post_deploy_info() {
    echo -e "${GREEN}🎉 DeFi协议部署完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 接下来您可以：${NC}"
    echo "1. 查看部署日志: cat broadcast/DeployToFoundry.s.sol/$CHAIN_ID/run-latest.json"
    echo "2. 运行交互演示: forge script script/InteractWithContracts.s.sol --rpc-url $RPC_URL --broadcast"
    echo "3. 运行完整测试: forge test --match-contract SimplifiedDeFiFlowTest --via-ir -v"
    echo ""
    echo -e "${BLUE}🔗 有用的命令：${NC}"
    echo "- 查看账户余额: cast balance [ADDRESS] --rpc-url $RPC_URL"
    echo "- 调用合约: cast call [CONTRACT] [SIGNATURE] --rpc-url $RPC_URL"
    echo "- 发送交易: cast send [CONTRACT] [SIGNATURE] [ARGS] --rpc-url $RPC_URL --private-key [PRIVATE_KEY]"
}

# 主逻辑
case "$1" in
    "help"|"-h"|"--help")
        show_help
        ;;
    "compile")
        compile_contracts
        ;;
    "deploy")
        check_anvil
        compile_contracts
        deploy_contracts
        show_post_deploy_info
        ;;
    "test")
        run_tests
        ;;
    "all"|"")
        check_anvil
        compile_contracts
        deploy_contracts
        echo ""
        run_tests
        echo ""
        show_post_deploy_info
        ;;
    *)
        echo -e "${RED}❌ 未知选项: $1${NC}"
        show_help
        exit 1
        ;;
esac

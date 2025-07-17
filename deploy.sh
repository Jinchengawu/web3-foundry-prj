#!/bin/bash
###
 # @Author: dreamworks.cnn@gmail.com
 # @Date: 2025-07-17 20:26:33
 # @LastEditors: dreamworks.cnn@gmail.com
 # @LastEditTime: 2025-07-17 20:55:13
 # @FilePath: /web3-foundry-prj/deploy.sh
 # @Description: 
 # 
 # Copyright (c) 2025 by ${git_name_email}, All Rights Reserved. 
### 

# 部署脚本 - MyToken 到 Sepolia 测试网
# 使用方法: ./deploy.sh

set -e

echo "开始部署 MyToken 到 Sepolia 测试网..."

# 检查环境变量文件
if [ ! -f .env ]; then
    echo "错误: 未找到 .env 文件"
    echo "请创建 .env 文件并设置以下变量:"
    echo "DEPLOYER_ADDRESS=你的钱包地址"
    echo "PRIVATE_KEY=你的私钥(不含0x前缀)"
    echo "SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID"
    echo "ETHERSCAN_API_KEY=你的Etherscan API密钥"
    exit 1
fi

# 加载环境变量
export $(cat .env | grep -v '^#' | xargs)

# 验证必要的环境变量
if [ -z "$DEPLOYER_ADDRESS" ]; then
    echo "错误: 未设置 DEPLOYER_ADDRESS"
    echo "请在 .env 文件中设置你的钱包地址"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "错误: 未设置 PRIVATE_KEY"
    echo "请在 .env 文件中设置你的私钥(不含0x前缀)"
    exit 1
fi

# 设置默认 RPC URL (如果未提供)
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo " 警告: 未设置 SEPOLIA_RPC_URL，使用默认 Sepolia RPC"
    SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/your-project-id"
fi

echo "📋 部署配置:"
echo "  部署者地址: $DEPLOYER_ADDRESS"
echo "  RPC URL: $SEPOLIA_RPC_URL"
echo "  网络: Sepolia"

# 编译合约 - 只编译 MyToken 相关文件
echo "🔨 编译合约..."
forge build --contracts src/W2/D4/foundry.sol script/foundry.s.sol

# 运行部署脚本
echo "🚀 执行部署脚本..."
forge script script/foundry.s.sol:MyTokenScript \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --verify \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    -vvvv

echo "✅ 部署完成!"
echo "📝 请检查上面的输出获取合约地址" 
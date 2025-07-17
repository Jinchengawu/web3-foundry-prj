# MyToken 部署指南

本指南将帮助你使用完善的脚本部署 MyToken 合约到不同的网络，避免重复输入命令行参数。

## 📋 目录

- [环境准备](#环境准备)
- [配置设置](#配置设置)
- [部署方式](#部署方式)
- [脚本说明](#脚本说明)
- [故障排除](#故障排除)

## 🔧 环境准备

### 1. 安装依赖

确保已安装 Foundry：
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 获取必要信息

- **钱包地址**: 你的以太坊钱包地址
- **私钥**: 钱包的私钥（不含0x前缀）
- **RPC URL**: 网络提供商的RPC端点
- **Etherscan API Key**: 用于合约验证（可选）

## ⚙️ 配置设置

### 1. 创建环境变量文件

创建 `.env` 文件并设置以下变量：

```bash
# 部署者信息
DEPLOYER_ADDRESS=0x1234567890123456789012345678901234567890
PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

# 网络配置
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# 合约验证
ETHERSCAN_API_KEY=your_etherscan_api_key

# 代币配置（可选，有默认值）
TOKEN_NAME=MyToken-WJK
TOKEN_SYMBOL=MTK-WJK
INITIAL_SUPPLY=10000000000000000000000000000
```

### 2. 设置文件权限

```bash
chmod +x deploy.sh
chmod +x scripts/deploy.js
```

## 🚀 部署方式

### 方式一：使用 Bash 脚本（推荐）

```bash
# 部署到 Sepolia 测试网
./deploy.sh

# 或者直接使用 forge 命令
forge script script/foundry.s.sol:MyTokenScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv
```

### 方式二：使用 Node.js 脚本

```bash
# 部署到 Sepolia（默认）
node scripts/deploy.js

# 部署到指定网络
node scripts/deploy.js sepolia
node scripts/deploy.js mainnet
node scripts/deploy.js anvil
```

### 方式三：使用高级配置脚本

```bash
# 使用 DeployConfig 脚本（支持多网络自动检测）
forge script script/DeployConfig.s.sol:DeployConfig \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv
```

## 📝 脚本说明

### 1. `script/foundry.s.sol` - 基础部署脚本

**功能**：
- 基础代币部署
- 环境变量验证
- 部署结果验证
- 详细日志输出

**特点**：
- 简单易用
- 适合快速部署
- 包含基本验证

### 2. `script/DeployConfig.s.sol` - 高级配置脚本

**功能**：
- 多网络自动检测
- 结构化配置管理
- 完整的部署验证
- 详细的部署信息输出

**特点**：
- 支持多种网络
- 配置更加灵活
- 验证更加完整

### 3. `deploy.sh` - Bash 部署脚本

**功能**：
- 环境检查
- 自动编译
- 一键部署
- 错误处理

**特点**：
- 自动化程度高
- 适合CI/CD
- 错误提示友好

### 4. `scripts/deploy.js` - Node.js 部署脚本

**功能**：
- 多网络支持
- 彩色输出
- 环境变量管理
- 灵活的配置选项

**特点**：
- 用户体验好
- 支持多种部署方式
- 错误处理完善

## 🔍 验证部署

部署成功后，你可以通过以下方式验证：

### 1. 检查合约地址

脚本会输出部署的合约地址，格式类似：
```
✅ 合约已部署到: 0x1234567890123456789012345678901234567890
```

### 2. 在 Etherscan 上查看

访问 `https://sepolia.etherscan.io/address/合约地址` 查看合约详情。

### 3. 验证合约功能

```bash
# 检查代币名称
cast call 合约地址 "name()" --rpc-url $SEPOLIA_RPC_URL

# 检查代币符号
cast call 合约地址 "symbol()" --rpc-url $SEPOLIA_RPC_URL

# 检查总供应量
cast call 合约地址 "totalSupply()" --rpc-url $SEPOLIA_RPC_URL
```

## 🛠️ 故障排除

### 常见问题

1. **环境变量未设置**
   ```
   ❌ 错误: 未设置 DEPLOYER_ADDRESS
   ```
   **解决方案**: 检查 `.env` 文件是否正确设置

2. **私钥与地址不匹配**
   ```
   ❌ Private key does not match deployer address
   ```
   **解决方案**: 确保私钥对应正确的钱包地址

3. **RPC URL 无效**
   ```
   ❌ 错误: 网络 sepolia 缺少 RPC URL
   ```
   **解决方案**: 检查 RPC URL 是否正确设置

4. **Gas 费用不足**
   ```
   ❌ 部署失败: insufficient funds
   ```
   **解决方案**: 确保钱包中有足够的 ETH 支付 Gas 费用

### 调试模式

启用详细日志输出：
```bash
forge script script/foundry.s.sol:MyTokenScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vvvv
```

### 本地测试

使用 Anvil 进行本地测试：
```bash
# 启动本地节点
anvil

# 在另一个终端部署
node scripts/deploy.js anvil
```

## 📞 支持

如果遇到问题，请检查：
1. Foundry 版本是否最新
2. 环境变量是否正确设置
3. 网络连接是否正常
4. 钱包余额是否充足

---

**注意**: 请妥善保管你的私钥，不要将其提交到版本控制系统中。 
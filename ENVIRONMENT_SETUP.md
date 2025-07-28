# 环境变量配置指南

## 概述
本项目的部署脚本需要配置一些环境变量才能正常工作。请按照以下步骤进行配置。

## 步骤 1: 创建环境变量文件

```bash
# 复制示例文件
cp .env.example .env

# 编辑 .env 文件
nano .env  # 或者使用你喜欢的编辑器
```

## 步骤 2: 配置必要的环境变量

### 1. 钱包配置

#### DEPLOYER_ADDRESS
你的以太坊钱包地址（用于部署合约）

**获取方式:**
- MetaMask: 账户页面复制地址
- 其他钱包: 导出或复制钱包地址

**格式示例:**
```
DEPLOYER_ADDRESS=
```

#### PRIVATE_KEY
你的钱包私钥（用于签名交易）

**⚠️ 安全警告:**
- 永远不要分享你的私钥
- 建议使用测试钱包的私钥
- 确保 .env 文件已添加到 .gitignore

**获取方式:**
- MetaMask: 账户详情 → 导出私钥
- 其他钱包: 导出私钥功能

**格式示例:**
```
PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### 2. 网络配置

#### SEPOLIA_RPC_URL
Sepolia 测试网的 RPC 端点

**推荐提供商:**

**Infura:**
```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
```

**Alchemy:**
```
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```

**QuickNode:**
```
SEPOLIA_RPC_URL=https://your-endpoint.quiknode.pro/YOUR_API_KEY/
```

**获取方式:**
1. 注册上述任一服务商账户
2. 创建新项目
3. 复制提供的 RPC URL

#### MAINNET_RPC_URL (可选)
主网 RPC 端点（格式同上）

### 3. 合约验证配置

#### ETHERSCAN_API_KEY
Etherscan API 密钥（用于合约验证）

**获取方式:**
1. 访问 https://etherscan.io/apis
2. 注册/登录账户
3. 创建新的 API 密钥

**格式示例:**
```
ETHERSCAN_API_KEY=YourApiKeyToken
```

## 步骤 3: 验证配置

运行部署脚本检查配置是否正确：

```bash
node scripts/deploy.js
```

如果配置正确，你应该看到：
```
✅ 环境配置检查通过
```

## 常见问题

### Q: 如何获取测试网 ETH？
A: 使用 Sepolia 水龙头：
- https://sepoliafaucet.com/
- https://faucet.sepolia.dev/

### Q: 私钥格式错误？
A: 确保私钥是64位十六进制字符串，不包含 "0x" 前缀

### Q: RPC URL 连接失败？
A: 检查网络连接和 API 密钥是否正确

### Q: 合约验证失败？
A: 确保 ETHERSCAN_API_KEY 正确设置

## 安全建议

1. **使用测试钱包**: 部署时使用专门的测试钱包
2. **保护私钥**: 永远不要提交包含真实私钥的文件到版本控制
3. **环境隔离**: 为不同环境（测试/生产）使用不同的钱包
4. **定期轮换**: 定期更换 API 密钥和私钥

## 示例 .env 文件

```bash
# 部署者配置
DEPLOYER_ADDRESS=
PRIVATE_KEY=

# 网络配置
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-project-id
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your-project-id

# Etherscan API密钥
ETHERSCAN_API_KEY=YourEtherscanApiKey
``` 
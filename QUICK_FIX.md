# 快速修复指南

## 当前状态
✅ 环境变量加载正常  
✅ 钱包地址和私钥配置正确  
❌ RPC URL 仍使用示例值

## 需要修复的问题

### 1. 更新 SEPOLIA_RPC_URL
当前值：`https://sepolia.infura.io/v3/YOUR_PROJECT_ID`

需要替换为真实的 Infura 项目 ID：

#### 获取 Infura 项目 ID 的步骤：
1. 访问 https://infura.io/
2. 注册/登录账户
3. 创建新项目或选择现有项目
4. 复制项目 ID（不是完整的 URL）

#### 更新 .env 文件：
```bash
# 编辑 .env 文件
nano .env

# 将这一行：
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# 替换为（替换 YOUR_ACTUAL_PROJECT_ID）：
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_ACTUAL_PROJECT_ID
```

### 2. 可选：更新 ETHERSCAN_API_KEY
如果需要合约验证，请更新：
```bash
# 将这一行：
ETHERSCAN_API_KEY=你的Etherscan API密钥

# 替换为：
ETHERSCAN_API_KEY=YourActualEtherscanApiKey
```

## 验证修复
运行部署脚本检查是否修复：
```bash
node scripts/deploy.js
```

如果配置正确，应该看到：
- ✅ 环境配置检查通过
- 没有警告信息
- 部署过程开始

## 其他 RPC 提供商选项

如果不想使用 Infura，也可以使用：

### Alchemy
```
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```

### QuickNode
```
SEPOLIA_RPC_URL=https://your-endpoint.quiknode.pro/YOUR_API_KEY/
```

### 公共 RPC（不推荐用于生产）
```
SEPOLIA_RPC_URL=https://rpc.sepolia.org
``` 
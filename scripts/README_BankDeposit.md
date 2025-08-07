# TokenBankV4 存款脚本使用说明

## 📋 概述

本目录包含两个 JavaScript 脚本，用于与已部署的 TokenBankV4 银行自动化系统进行交互：

1. **bankDeposit.js** - 完整功能的存款脚本
2. **quickDeposit.js** - 简化的快速存款脚本

## 🎯 目标

通过脚本自动完成以下操作：
- 向 TokenBankV4 合约存入超过 1000 tokens 的金额
- 触发 Chainlink Automation 自动转移功能
- 将一半存款自动转移给 owner (`0xcC44277d1d6eC279Cd81e23111B1701758A3f82F`)

## 🏗️ 已部署的合约地址

```javascript
const CONTRACTS = {
    TokenV3: '0x9CEAee8E52B76F4C296aF6293675fB9b797fd0Af',         // ERC20 代币合约
    TokenBankV4: '0xe5c40B5F76700c3177E76c148D1A6b8569c69Bd9',      // 银行合约
    BankAutomation: '0xBE3eb1794d87a9fCa05C603E95Bb91828C80Aec5',  // 自动化合约
    owner: '0xcC44277d1d6eC279Cd81e23111B1701758A3f82F'            // 合约所有者
};
```

## ⚙️ 系统配置

- **自动转移阈值**: 1000 tokens
- **检查间隔**: 300 秒 (5分钟)
- **最小转移间隔**: 3600 秒 (1小时)
- **网络**: Sepolia 测试网

## 🚀 使用方法

### 方法一：使用快速存款脚本 (推荐)

```bash
# 运行快速存款脚本
node scripts/quickDeposit.js
```

### 方法二：使用完整功能脚本

```bash
# 运行完整存款脚本
node scripts/bankDeposit.js
```

## 📝 脚本功能对比

| 功能 | quickDeposit.js | bankDeposit.js |
|------|-----------------|----------------|
| 基础存款功能 | ✅ | ✅ |
| 自动铸造代币 | ✅ | ✅ |
| 自动授权 | ✅ | ✅ |
| 详细状态检查 | ❌ | ✅ |
| 自动化状态监控 | ❌ | ✅ |
| 操作日志保存 | ❌ | ✅ |
| 彩色输出 | ❌ | ✅ |

## 🔧 前置要求

### 1. 环境配置

确保 `.env` 文件包含以下配置：

```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=0x your_private_key_here
```

### 2. 依赖安装

```bash
npm install ethers dotenv
```

### 3. 账户准备

- 确保账户有足够的 Sepolia ETH 用于支付 gas 费用
- 脚本会自动铸造所需的测试代币

## 💡 脚本执行流程

1. **初始化连接** - 连接到 Sepolia 网络和合约
2. **检查配置** - 验证银行合约的阈值和设置
3. **计算存款金额** - 自动计算超过阈值的存款金额 (阈值 + 额外代币)
4. **铸造代币** - 如果余额不足，自动铸造所需代币
5. **授权合约** - 授权银行合约使用代币
6. **执行存款** - 向银行合约存入代币
7. **状态检查** - 验证存款是否成功且超过阈值
8. **自动化监控** - 检查 Chainlink Automation 状态

## 📊 预期结果

### 成功执行后：

1. **用户余额** - 减少存款金额的代币
2. **银行总存款** - 增加到超过 1000 tokens
3. **自动化触发** - Chainlink Automation 检测到需要转移
4. **自动转移** - 约 50% 的存款将转移给 owner

### 示例输出：

```
🎯 快速存款脚本 - TokenBankV4
========================================
👤 用户地址: 0x...
🎯 自动转移阈值: 1000.0 tokens
💰 计划存款: 1200.0 tokens
📊 当前代币余额: 0.0 tokens
🪙 余额不足，正在铸造代币...
📤 铸造交易: 0x...
✅ 代币铸造成功!
🔑 正在授权银行合约...
📤 授权交易: 0x...
✅ 授权成功!
💳 正在存款...
📤 存款交易: 0x...
✅ 存款成功!
📈 银行总存款: 1200.0 tokens
🎯 阈值: 1000.0 tokens
🎉 存款已超过阈值! Chainlink Automation 将自动执行转移!
💸 将转移约 600.0 tokens 给 owner
⏰ 请等待自动化执行...
```

## 🔍 故障排除

### 常见问题：

1. **连接失败**
   - 检查 `.env` 文件中的 RPC URL 是否正确
   - 确认网络连接正常

2. **余额不足**
   - 脚本会自动铸造代币，确保有足够的 ETH 支付 gas

3. **授权失败**
   - 检查私钥是否正确
   - 确认账户有足够的 ETH

4. **自动化未触发**
   - 确认存款金额超过阈值
   - 检查 Chainlink Automation 是否已注册合约

## 🔗 相关链接

- [Chainlink Automation](https://automation.chain.link/)
- [Sepolia 测试网](https://sepolia.etherscan.io/)
- [合约验证地址](https://sepolia.etherscan.io/address/${CONTRACTS.TokenBankV4})

## 📞 技术支持

如果遇到问题：
1. 检查控制台输出的错误信息
2. 确认网络和合约地址
3. 验证 .env 配置
4. 查看交易哈希在区块链浏览器中的状态
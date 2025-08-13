# RebaseToken - 通缩型ERC20 Token

## 项目概述

RebaseToken 是一个基于以太坊的通缩型ERC20 Token，通过rebase机制实现每年1%的通缩。该项目旨在演示和理解rebase型Token的核心实现原理。

## 核心特性

- ✅ **起始发行量**: 1亿枚Token
- ✅ **通缩机制**: 每年在上一年的基础上下降1%
- ✅ **实时余额显示**: `balanceOf()` 方法正确反映通缩后的用户余额
- ✅ **完全兼容ERC20标准**: 支持所有标准ERC20功能
- ✅ **安全的数学计算**: 使用SafeMath防止溢出
- ✅ **权限控制**: 只有合约所有者可以执行rebase操作
- ✅ **时间间隔控制**: 防止频繁rebase攻击

## 技术架构

### Rebase机制原理

RebaseToken采用指数调整机制实现通缩：

1. **不改变用户持有的Token数量**: 用户的原始余额保持不变
2. **通过调整总供应量实现通缩**: 通过rebase指数调整显示余额
3. **用户余额比例保持不变**: 所有用户的相对占比维持不变

### 核心算法

```
实际余额 = 原始余额 × rebase指数 ÷ 1e18
rebase指数 = 前一个指数 × (1 - 年通缩率 ÷ 10000)
```

### 数据结构

- `_totalSupply`: 当前总供应量
- `_rebaseIndex`: rebase指数（精度: 1e18）
- `_balances`: 用户原始余额映射
- `_lastRebaseTime`: 上次rebase时间戳
- `_annualDeflation`: 年通缩率（1% = 100）

## 文件结构

```
rebaseToken/
├── README.md                    # 项目说明文档
├── 工程设计文档.md              # 详细设计文档
├── RebaseToken.sol             # 主合约实现
└── readme.md                   # 原始需求文档
```

## 快速开始

### 环境要求

- Solidity ^0.8.19
- Foundry
- Node.js (用于JavaScript脚本)

### 安装依赖

```bash
# 安装OpenZeppelin合约
forge install OpenZeppelin/openzeppelin-contracts
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-test testRebaseAfterOneDay

# 显示详细日志
forge test -vvv
```

### 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key

# 部署到本地网络
forge script script/DeployRebaseToken.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/DeployRebaseToken.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

### 运行演示脚本

```bash
# 使用Hardhat运行演示
npx hardhat run scripts/rebaseTokenDemo.js --network localhost
```

## 核心功能

### 1. 初始化

```solidity
RebaseToken token = new RebaseToken("Rebase Token", "RBT");
// 初始总供应量: 100,000,000 RBT
// 初始rebase指数: 1e18
// 年通缩率: 1%
```

### 2. 查询余额

```solidity
// 获取用户实际余额（已考虑rebase）
uint256 balance = token.balanceOf(userAddress);

// 获取当前总供应量
uint256 totalSupply = token.totalSupply();

// 获取rebase指数
uint256 rebaseIndex = token.getRebaseIndex();
```

### 3. 执行Rebase

```solidity
// 只有合约所有者可以执行
token.rebase();
// 需要满足时间间隔要求（至少1天）
```

### 4. 转账功能

```solidity
// 标准转账
token.transfer(toAddress, amount);

// 授权转账
token.approve(spenderAddress, amount);
token.transferFrom(fromAddress, toAddress, amount);
```

## 测试用例

项目包含全面的测试用例：

### 基础功能测试
- ✅ 初始状态验证
- ✅ 转账功能测试
- ✅ 授权功能测试

### Rebase功能测试
- ✅ 单次rebase测试
- ✅ 多次rebase测试
- ✅ 时间间隔控制测试

### 余额计算测试
- ✅ 余额比例保持不变验证
- ✅ 通缩效果验证
- ✅ 边界条件测试

### 安全测试
- ✅ 权限控制测试
- ✅ 数值安全测试
- ✅ 重入攻击防护测试

## 安全考虑

### 1. 权限控制
- 只有合约所有者可以执行rebase操作
- 防止频繁rebase攻击

### 2. 数值安全
- 使用SafeMath库防止溢出
- 精确的数学计算避免精度损失
- 合理的rebase时间间隔控制

### 3. 重入攻击防护
- 使用ReentrancyGuard
- 状态更新在外部调用之前

## 使用示例

### 基本使用流程

1. **部署合约**
```solidity
RebaseToken token = new RebaseToken("Rebase Token", "RBT");
```

2. **转账给用户**
```solidity
token.transfer(userAddress, 1000000 * 10**18);
```

3. **执行Rebase**
```solidity
// 等待1天后
token.rebase();
```

4. **查看效果**
```solidity
uint256 newBalance = token.balanceOf(userAddress);
uint256 newTotalSupply = token.totalSupply();
```

### 长期效果示例

假设初始总供应量为1亿枚：

- **1年后**: 99,000,000枚 (减少1%)
- **5年后**: 95,099,005枚 (减少约4.9%)
- **10年后**: 90,438,207枚 (减少约9.6%)

## 监控和维护

### 关键指标
- Rebase执行频率
- 总供应量变化趋势
- 用户余额变化
- Gas消耗情况

### 维护建议
- 定期检查rebase执行情况
- 监控异常交易
- 更新安全参数

## 扩展功能

### 可能的改进方向
1. **动态通缩率**: 根据市场条件调整通缩率
2. **治理机制**: 添加DAO治理功能
3. **批量操作**: 支持批量转账和授权
4. **事件监控**: 增强事件记录和监控

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request来改进项目。

## 联系方式

- 作者: dreamworks.cnn@gmail.com
- 项目地址: [GitHub Repository]

---

**注意**: 这是一个教育项目，用于理解rebase型Token的实现原理。在生产环境中使用前，请进行充分的安全审计。
# MemeFactory 合约文档

## 概述

MemeFactory 是一个基于最小代理模式（EIP-1167）的 Meme 代币发射平台。该平台允许用户创建和铸造 ERC20 代币，同时实现了公平的费用分配机制。

## 主要特性

### 1. 最小代理模式
- 使用 OpenZeppelin 的 `Clones` 库实现最小代理模式
- 大幅降低部署新 Meme 代币的 Gas 成本
- 所有 Meme 代币共享同一个实现合约

### 2. 费用分配机制
- **创建者费用**: 99% 的铸造费用分配给 Meme 创建者
- **项目方费用**: 1% 的铸造费用分配给项目方
- 自动费用分配，无需手动操作

### 3. 公平铸造机制
- 每次铸造固定数量的代币（`perMint`）
- 防止一次性铸造所有代币
- 确保代币的公平分配

## 合约架构

### Meme 合约
```solidity
contract Meme is ERC20, Ownable {
    uint256 public totalSupplyLimit;  // 总供应量限制
    uint256 public perMint;           // 每次铸造数量
    uint256 public price;             // 每个代币价格
    uint256 public mintedAmount;      // 已铸造数量
    bool public initialized;          // 初始化状态
}
```

### MemeFactory 合约
```solidity
contract MemeFactory is Ownable {
    address public immutable memeImplementation;  // 实现合约地址
    mapping(address => MemeInfo) public memeInfos; // Meme 信息映射
}
```

## 核心功能

### 1. 部署 Meme 代币
```solidity
function deployMeme(
    string memory symbol,
    uint256 totalSupply,
    uint256 perMint,
    uint256 price
) external returns (address)
```

**参数说明:**
- `symbol`: 代币符号（如 "DOGE"）
- `totalSupply`: 总供应量
- `perMint`: 每次铸造数量
- `price`: 每个代币价格（wei）

**示例:**
```solidity
// 部署一个总供应量为 1,000,000，每次铸造 1,000 个，单价 0.001 ETH 的代币
address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
```

### 2. 铸造 Meme 代币
```solidity
function mintMeme(address tokenAddr) external payable
```

**功能:**
- 铸造指定数量的代币
- 自动分配费用给创建者和项目方
- 退还多余的 ETH

**示例:**
```solidity
// 铸造代币，支付所需费用
uint256 mintCost = factory.getMintCost(memeToken);
factory.mintMeme{value: mintCost}(memeToken);
```

### 3. 查询功能
```solidity
// 获取 Meme 信息
function getMemeInfo(address tokenAddr) external view returns (MemeInfo memory)

// 检查是否为有效的 Meme 代币
function isMeme(address tokenAddr) external view returns (bool)

// 获取铸造费用
function getMintCost(address tokenAddr) external view returns (uint256)
```

## 费用分配计算

### 费用分配比例
- **创建者费用**: 99% (`CREATOR_FEE_RATIO = 9900`)
- **项目方费用**: 1% (`PROJECT_FEE_RATIO = 100`)
- **总比例**: 100% (`FEE_DENOMINATOR = 10000`)

### 计算示例
假设铸造费用为 1 ETH：
- 创建者获得: `1 ETH × 99% = 0.99 ETH`
- 项目方获得: `1 ETH × 1% = 0.01 ETH`

## 安全特性

### 1. 访问控制
- 使用 OpenZeppelin 的 `Ownable` 合约
- 只有工厂合约所有者可以调用 `emergencyWithdraw`

### 2. 参数验证
- 总供应量必须大于 0
- 每次铸造数量必须大于 0 且不超过总供应量
- 价格必须大于 0

### 3. 铸造限制
- 每次铸造数量必须等于 `perMint`
- 不能超过总供应量限制
- 铸造前检查是否还有剩余供应量

## 部署和使用

### 1. 编译合约
```bash
forge build
```

### 2. 运行测试
```bash
forge test --match-contract MemeFactoryTest -vv
```

### 3. 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key

# 部署到本地网络
forge script script/MemeFactory.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/MemeFactory.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## 测试用例

合约包含完整的测试用例，覆盖以下场景：

1. **基本功能测试**
   - 部署 Meme 代币
   - 铸造代币
   - 费用分配验证

2. **边界条件测试**
   - 无效参数验证
   - 铸造数量限制
   - 支付不足/超额处理

3. **权限测试**
   - 所有者权限验证
   - 紧急提取功能

4. **多次铸造测试**
   - 连续铸造验证
   - 供应量耗尽处理

## Gas 优化

### 1. 最小代理模式
- 部署新 Meme 代币仅需约 50,000 gas
- 相比直接部署节省约 90% 的 gas

### 2. 存储优化
- 使用紧凑的数据结构
- 避免重复存储

### 3. 函数优化
- 批量操作减少交易次数
- 合理的函数可见性设置

## 事件

合约发出以下事件用于前端集成：

```solidity
event MemeDeployed(
    address indexed token,
    address indexed creator,
    string symbol,
    uint256 totalSupply,
    uint256 perMint,
    uint256 price
);

event MemeMinted(
    address indexed token,
    address indexed buyer,
    uint256 amount,
    uint256 cost
);

event FeesDistributed(
    address indexed token,
    address indexed creator,
    uint256 creatorFee,
    uint256 projectFee
);
```

## 注意事项

1. **初始化**: 每个代理合约只能初始化一次
2. **费用分配**: 如果项目方地址无法接收 ETH，费用将留在合约中
3. **Gas 费用**: 铸造时需要支付额外的 gas 费用
4. **网络选择**: 建议在测试网充分测试后再部署到主网

## 许可证

MIT License 
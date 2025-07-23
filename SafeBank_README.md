# SafeBank 多签钱包合约

## 概述

SafeBank 是一个基于智能合约的多签钱包系统，实现了类似 Safe Wallet 的功能。它允许创建 2/3 多签账户，支持 ERC20 代币的存入和转出，并且可以与 Bank 合约集成。

## 功能特性

### 1. 多签账户管理
- 创建多签账户，支持多个所有者
- 可配置所需签名数量（至少2个）
- 支持订单审批机制

### 2. ERC20 代币管理
- 支持任意 ERC20 代币的存入
- 多签审批的代币转出
- 余额查询功能

### 3. Bank 合约集成
- 将 Bank 合约的管理员设置为多签账户
- 从多签中发起对 Bank 的 withdraw 调用

## 合约地址

部署后，您需要记录以下地址：
- **SafeBank 合约地址**: [部署后填写]
- **ERC20V2 代币地址**: [部署后填写]

## 使用流程

### 步骤 1: 创建多签账户

```solidity
// 创建包含3个所有者的多签账户，需要2个签名
address[] memory owners = [address1, address2, address3];
uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
```

### 步骤 2: 存入 ERC20 代币

```solidity
// 首先授权 SafeBank 合约使用代币
token.approve(safeBankAddress, amount);

// 存入代币到多签账户
safeBank.depositToSafeBank(accountId, tokenAddress, amount);
```

### 步骤 3: 创建转出订单

```solidity
// 创建从多签中转出代币的订单
safeBank.createWithdrawOrder(
    accountId, 
    tokenAddress, 
    amount, 
    recipientAddress, 
    deadline
);
```

### 步骤 4: 审批订单

```solidity
// 多签所有者审批订单
safeBank.approveOrder(accountId, orderId);

// 当达到所需签名数量时，订单会自动执行
```

### 步骤 5: 设置 Bank 合约管理员

```solidity
// 将 Bank 合约的管理员设置为多签账户
safeBank.setBankOwnerToSafeBank(accountId);
```

### 步骤 6: 从 Bank 合约提取代币

```solidity
// 创建从 Bank 合约提取代币的订单
safeBank.createBankWithdrawOrder(accountId, amount, deadline);

// 审批并执行订单
safeBank.approveOrder(accountId, orderId);
```

## 主要函数说明

### 账户管理
- `createSafeBankAccount(address[] owners, uint256 requiredSignatures)` - 创建多签账户
- `getSafeBankAccount(uint256 accountId)` - 查询账户信息

### 代币操作
- `depositToSafeBank(uint256 accountId, address token, uint256 amount)` - 存入代币
- `createWithdrawOrder(uint256 accountId, address token, uint256 amount, address to, uint256 deadline)` - 创建转出订单
- `getTokenBalance(uint256 accountId, address token)` - 查询代币余额

### 订单管理
- `approveOrder(uint256 accountId, uint256 orderId)` - 审批订单
- `rejectOrder(uint256 accountId, uint256 orderId)` - 拒绝订单
- `cancelOrder(uint256 accountId, uint256 orderId)` - 取消订单
- `executeOrder(uint256 accountId, uint256 orderId)` - 执行订单
- `getOrder(uint256 accountId, uint256 orderId)` - 查询订单信息

### Bank 集成
- `setBankOwnerToSafeBank(uint256 accountId)` - 设置 Bank 管理员
- `createBankWithdrawOrder(uint256 accountId, uint256 amount, uint256 deadline)` - 创建 Bank 提取订单
- `executeBankWithdrawOrder(uint256 accountId, uint256 orderId)` - 执行 Bank 提取订单

## 安全特性

1. **多签验证**: 所有重要操作都需要多个所有者签名
2. **时间限制**: 订单有过期时间，防止长期悬而未决
3. **权限控制**: 只有多签所有者才能执行相关操作
4. **余额检查**: 确保有足够余额才允许转出
5. **状态管理**: 订单状态清晰，防止重复执行

## 事件

合约会发出以下事件，方便前端监听：

- `SafeBankAccountCreated` - 多签账户创建
- `OrderCreated` - 订单创建
- `OrderApproved` - 订单审批
- `OrderRejected` - 订单拒绝
- `OrderExecuted` - 订单执行
- `OrderCancelled` - 订单取消
- `TokenDeposited` - 代币存入
- `TokenWithdrawn` - 代币转出

## 测试

运行测试以确保合约功能正常：

```bash
forge test --match-contract SafeBankTest -vv
```

## 部署

使用以下命令部署合约：

```bash
forge script script/SafeBank.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## 注意事项

1. 确保在创建多签账户时至少指定2个所有者
2. 所需签名数量不能超过所有者数量
3. 在存入代币前需要先授权 SafeBank 合约
4. 订单有截止时间，过期后无法执行
5. 只有订单创建者可以取消订单
6. 任何所有者都可以拒绝订单

## 与 Safe Wallet 的集成

虽然这个合约实现了类似 Safe Wallet 的功能，但如果您需要使用真正的 Safe Wallet，可以：

1. 在 Safe Wallet 支持的测试网上创建 Safe 钱包
2. 将 SafeBank 合约的地址添加到 Safe 钱包的模块列表中
3. 通过 Safe 钱包的界面来管理多签操作

这样可以获得 Safe Wallet 提供的额外安全性和用户界面优势。 
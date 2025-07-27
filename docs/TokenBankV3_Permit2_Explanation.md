# TokenBankV3 DepositWithPermit2 功能详解

## 概述

`depositWithPermit2` 是 `TokenBankV3` 合约中的一个创新方法，它结合了 EIP-2612 permit 标准和传统的 ERC20 转账功能，为用户提供了更灵活的存款方式。

## 功能特点

### 1. 通用性
- 支持任何 ERC20 代币
- 自动检测代币是否支持 permit 功能
- 向后兼容不支持 permit 的代币

### 2. 用户体验
- 支持 permit 的代币：无需提前 approve
- 不支持 permit 的代币：需要提前 approve
- 只需要一个交易完成存款

### 3. 安全性
- 遵循 EIP-712 签名标准
- 支持签名过期时间
- 防重放攻击保护

## 实现原理

### 1. 方法签名
```solidity
function depositWithPermit2(
    address owner,
    address tokenAddress,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public
```

### 2. 工作流程
```solidity
// 1. 参数验证
if (tokenAddress == address(0)) {
    revert Permit2InvalidToken(tokenAddress);
}
if (amount == 0) {
    revert Permit2InvalidValue(amount);
}
if (block.timestamp > deadline) {
    revert PermitDepositExpiredSignature(deadline);
}

// 2. 尝试通过 permit 获取授权
try this.tryPermit(tokenAddress, owner, address(this), amount, deadline, v, r, s) {
    // permit 成功
} catch {
    // permit 失败，继续执行（用户需要提前 approve）
}

// 3. 执行转账
require(IERC20(tokenAddress).transferFrom(owner, address(this), amount), "Transfer failed");

// 4. 更新余额
balances[owner] += amount;
totalDeposit += amount;
userTokenBalances[owner][tokenAddress] += amount;

// 5. 发出事件
emit DepositWithPermit2(owner, tokenAddress, amount, deadline);
```

### 3. Permit 尝试机制
```solidity
function tryPermit(
    address tokenAddress,
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external {
    (bool success, ) = tokenAddress.call(
        abi.encodeWithSignature(
            "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        )
    );
    
    if (!success) {
        revert("Permit failed");
    }
}
```

## 使用场景

### 场景一：代币支持 Permit（推荐）
```javascript
// 1. 创建 permit 签名
const tokenNonce = await token.nonces(userAddress);
const tokenDomain = {
    name: await token.name(),
    version: '1',
    chainId: chainId,
    verifyingContract: tokenAddress
};

const tokenTypes = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const tokenMessage = {
    owner: userAddress,
    spender: tokenBankAddress,
    value: amount.toString(),
    nonce: tokenNonce.toString(),
    deadline: deadline.toString()
};

const signature = await wallet._signTypedData(tokenDomain, tokenTypes, tokenMessage);
const { v, r, s } = ethers.utils.splitSignature(signature);

// 2. 调用 depositWithPermit2
await tokenBank.depositWithPermit2(
    userAddress,
    tokenAddress,
    amount,
    deadline,
    v,
    r,
    s
);
```

### 场景二：代币不支持 Permit
```javascript
// 1. 提前 approve
await token.approve(tokenBankAddress, amount);

// 2. 调用 depositWithPermit2（permit 会失败，但 transferFrom 会成功）
await tokenBank.depositWithPermit2(
    userAddress,
    tokenAddress,
    amount,
    deadline,
    0, // 无效签名
    0,
    0
);
```

## 与其他方法的对比

| 特性 | 传统 deposit | permitDeposit | depositWithPermit2 |
|------|-------------|---------------|-------------------|
| 是否需要 approve | ✅ 是 | ✅ 是 | 条件性 |
| 交易数量 | 2个 | 1-2个 | 1个 |
| 代币兼容性 | 所有 ERC20 | 所有 ERC20 | 所有 ERC20 |
| Permit 支持 | ❌ 否 | ❌ 否 | ✅ 是 |
| 用户体验 | 一般 | 良好 | 优秀 |
| Gas 消耗 | 中等 | 较低 | 中等 |

## 安全考虑

### 1. 签名验证
- 使用 EIP-712 标准确保签名安全
- 验证签名者必须是代币持有者
- 检查签名过期时间

### 2. 重放攻击防护
- 代币的 permit 功能使用 nonce 防重放
- 签名包含过期时间

### 3. 错误处理
- 优雅处理不支持 permit 的代币
- 清晰的错误信息

## 错误定义

```solidity
error Permit2InvalidToken(address token);
error Permit2InvalidValue(uint256 value);
error PermitDepositExpiredSignature(uint256 deadline);
error PermitDepositInvalidSigner(address signer, address owner);
```

## 事件定义

```solidity
event DepositWithPermit2(
    address indexed owner, 
    address indexed token, 
    uint256 amount, 
    uint256 deadline
);
```

## 测试覆盖

### 1. 基本功能测试
- ✅ 正常存款流程
- ✅ 签名过期处理
- ✅ 无效签名处理
- ✅ 零金额处理
- ✅ 无效代币地址处理

### 2. 边界情况测试
- ✅ 支持 permit 的代币
- ✅ 不支持 permit 的代币
- ✅ 多种代币类型

## 部署和使用

### 1. 部署合约
```bash
forge script script/TokenBankV3.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### 2. 前端集成
```javascript
// 检查代币是否支持 permit
const hasPermit = await checkTokenPermitSupport(tokenAddress);

if (hasPermit) {
    // 使用 permit 签名
    await depositWithPermit2Example();
} else {
    // 使用传统 approve + deposit
    await depositWithPermit2ForNonPermitToken();
}
```

## 总结

`depositWithPermit2` 方法为 `TokenBankV3` 提供了：

1. **最大的兼容性**：支持所有 ERC20 代币
2. **最佳的用户体验**：支持 permit 的代币无需提前 approve
3. **统一的操作接口**：无论代币是否支持 permit，都使用同一个方法
4. **安全的实现**：遵循 EIP-712 标准，包含完整的错误处理

这个设计使得 `TokenBankV3` 能够为不同类型的代币提供最优的存款体验，同时保持向后兼容性。 
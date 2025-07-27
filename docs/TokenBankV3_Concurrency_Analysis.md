# TokenBankV3 并发场景分析

## 问题场景描述

用户当前在 TokenV3 中有 10 ETH，如果用户提前打包好 `permitDepositWithTokenPermit` 所需的签名参数（包含 10 ETH），并且提前对 TokenBankV3 进行了 approve，然后同时执行以下操作：

1. 对其他合约执行 Deposit
2. 对当前 TokenBankV3 执行 Deposit
3. 对当前 TokenBankV3 执行 permitDeposit

如果这些操作同时调用以太坊的不同节点，会出现什么问题？

## 并发执行的问题分析

### 1. 签名重放攻击

**问题描述**：
- 攻击者获取了用户的签名
- 攻击者可以多次调用 `permitDepositWithTokenPermit`
- 每次调用都会消耗用户的代币余额

**实际测试结果**：
✅ **已防护**：TokenV3 的 `permit` 使用了 nonce 机制，每次调用都会增加 nonce，防止签名重放。

```solidity
// TokenV3.permit 中的防重放机制
bytes32 structHash = keccak256(
    abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
);
```

**测试验证**：
```solidity
function testPermitDepositWithTokenPermitReplayAttack() public {
    // 第一次调用成功
    tokenBank.permitDepositWithTokenPermit(owner, amount, deadline, v, r, s);
    
    // 第二次调用失败（nonce 已增加）
    vm.expectRevert();
    tokenBank.permitDepositWithTokenPermit(owner, amount, deadline, v, r, s);
}
```

### 2. 余额竞争问题

**问题场景**：
```javascript
// 用户余额：10 ETH
// 交易1：其他合约 Deposit 6 ETH
// 交易2：TokenBankV3 Deposit 5 ETH
// 交易3：TokenBankV3 permitDeposit 10 ETH

// 可能的执行结果：
// 交易1：成功（余额变为 4 ETH）
// 交易2：失败（余额不足）
// 交易3：失败（余额不足）
```

**解决方案**：
在 `_executeDeposit` 中添加余额检查：

```solidity
function _executeDeposit(
    address owner,
    address tokenAddress,
    uint256 amount
) internal {
    // 检查用户余额是否足够
    uint256 userBalance = IERC20(tokenAddress).balanceOf(owner);
    if (userBalance < amount) {
        revert InsufficientTokenBalance(owner, userBalance, amount);
    }
    
    // 执行转账
    require(IERC20(tokenAddress).transferFrom(owner, address(this), amount), "Transfer failed");
    
    // 更新余额
    balances[owner] += amount;
    totalDeposit += amount;
    userTokenBalances[owner][tokenAddress] += amount;
}
```

### 3. Allowance 竞争问题

**问题场景**：
```javascript
// 用户对 TokenBankV3 approve：10 ETH
// 交易1：permitDeposit 6 ETH
// 交易2：permitDeposit 5 ETH

// 可能的执行结果：
// 交易1：成功（allowance 变为 4 ETH）
// 交易2：失败（allowance 不足）
```

**解决方案**：
在 `permitDeposit` 中添加 allowance 检查：

```solidity
function permitDeposit(
    address owner, 
    uint256 amount, 
    uint256 deadline, 
    uint8 v, 
    bytes32 r, 
    bytes32 s
) public {
    // 验证基本参数
    _validateDepositParams(owner, amount, deadline);
    
    // 验证 TokenBankV3 的 permitDeposit 签名
    _verifyPermitDepositSignature(owner, amount, deadline, v, r, s);
    
    // 检查 allowance 是否足够
    uint256 allowance = IERC20(address(token)).allowance(owner, address(this));
    if (allowance < amount) {
        revert InsufficientAllowance(owner, allowance, amount);
    }
    
    // 执行存款操作
    _executeDeposit(owner, address(token), amount);
    
    // 发出事件
    emit PermitDeposit(owner, amount, deadline);
}
```

**测试验证**：
```solidity
function testPermitDepositInsufficientAllowance() public {
    // Alice 只 approve 3 ETH，但尝试存款 5 ETH
    vm.startPrank(ALICE);
    tokenV3.approve(address(tokenBank), 3e18);
    vm.stopPrank();
    
    // 尝试存款 5 ETH 应该失败
    vm.expectRevert(abi.encodeWithSelector(
        TokenBankV3.InsufficientAllowance.selector,
        ALICE,
        3e18,
        amount
    ));
    
    tokenBank.permitDeposit(owner, amount, deadline, v, r, s);
}
```

## 不同方法的并发安全性对比

### 1. `permitDeposit` 方法

**安全性**：
- ✅ 使用 nonce 防重放攻击
- ✅ 验证 TokenBankV3 签名
- ✅ 检查 allowance
- ✅ 检查余额（通过 ERC20 的 transferFrom）

**并发问题**：
- ❌ 可能遇到 allowance 竞争
- ❌ 可能遇到余额竞争

### 2. `permitDepositWithTokenPermit` 方法

**安全性**：
- ✅ 使用 nonce 防重放攻击（TokenV3 的 permit）
- ✅ 验证代币 permit 签名
- ✅ 检查余额（通过 ERC20 的 transferFrom）

**并发问题**：
- ❌ 可能遇到余额竞争
- ✅ 不会遇到 allowance 竞争（permit 会重新授权）

### 3. `depositWithPermit2` 方法

**安全性**：
- ✅ 使用 nonce 防重放攻击（代币的 permit）
- ✅ 检查余额
- ✅ 支持任何 ERC20 代币

**并发问题**：
- ❌ 可能遇到余额竞争
- ✅ 不会遇到 allowance 竞争（permit 会重新授权）

## 最佳实践建议

### 1. 前端处理

```javascript
// 1. 检查用户余额
const userBalance = await token.balanceOf(userAddress);
if (userBalance < amount) {
    throw new Error("Insufficient balance");
}

// 2. 检查 allowance（对于 permitDeposit）
const allowance = await token.allowance(userAddress, tokenBankAddress);
if (allowance < amount) {
    throw new Error("Insufficient allowance");
}

// 3. 使用适当的 deadline
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期

// 4. 处理并发错误
try {
    await tokenBank.permitDepositWithTokenPermit(owner, amount, deadline, v, r, s);
} catch (error) {
    if (error.message.includes("InsufficientTokenBalance")) {
        // 余额不足，提示用户
    } else if (error.message.includes("InsufficientAllowance")) {
        // allowance 不足，提示用户重新 approve
    }
}
```

### 2. 合约优化

```solidity
// 1. 添加更详细的错误信息
error InsufficientTokenBalance(address owner, uint256 balance, uint256 amount);
error InsufficientAllowance(address owner, uint256 allowance, uint256 amount);

// 2. 添加事件记录
event DepositAttempt(address indexed owner, uint256 amount, bool success, string reason);

// 3. 添加批量操作支持
function batchDeposit(uint256[] calldata amounts) external {
    for (uint256 i = 0; i < amounts.length; i++) {
        try this.deposit(amounts[i]) {
            emit DepositAttempt(msg.sender, amounts[i], true, "");
        } catch Error(string memory reason) {
            emit DepositAttempt(msg.sender, amounts[i], false, reason);
        }
    }
}
```

## 总结

1. **签名重放攻击**：已通过 nonce 机制完全防护
2. **余额竞争**：通过余额检查提供更好的错误信息
3. **Allowance 竞争**：通过 allowance 检查提供更好的错误信息
4. **并发安全性**：`permitDepositWithTokenPermit` 和 `depositWithPermit2` 比 `permitDeposit` 更安全

建议用户优先使用 `permitDepositWithTokenPermit` 方法，因为它避免了 allowance 竞争问题，同时提供了更好的用户体验。 
# PERMIT_TYPEHASH 详解

## 什么是 PERMIT_TYPEHASH？

`PERMIT_TYPEHASH` 是 EIP-712 标准中用于类型化数据签名的一个重要组成部分。它是一个预计算的哈希值，用于标识特定的数据结构类型。

## 来源和计算方式

### 1. 基本定义

```solidity
bytes32 public constant PERMIT_TYPEHASH = 
    keccak256("PermitDeposit(address owner,uint256 amount,uint256 deadline)");
```

### 2. 计算过程

`PERMIT_TYPEHASH` 是通过对结构体类型字符串进行 keccak256 哈希计算得到的：

```javascript
// JavaScript 示例
const typeString = "PermitDeposit(address owner,uint256 amount,uint256 deadline)";
const permitTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeString));
```

### 3. 为什么使用这个格式？

这个格式遵循 EIP-712 标准：
- `PermitDeposit` - 函数/操作名称
- `address owner` - 代币持有者地址
- `uint256 amount` - 存款金额
- `uint256 deadline` - 签名过期时间

## 在 EIP-712 签名中的作用

### 1. 完整的签名流程

```solidity
// 1. 构建结构体哈希
bytes32 structHash = keccak256(abi.encode(
    PERMIT_TYPEHASH,  // 类型哈希
    owner,           // 用户地址
    amount,          // 存款金额
    deadline         // 过期时间
));

// 2. 构建完整的 EIP-712 哈希
bytes32 hash = keccak256(abi.encodePacked(
    "\x19\x01",           // EIP-712 前缀
    DOMAIN_SEPARATOR,     // 域分隔符
    structHash           // 结构体哈希
));

// 3. 从签名中恢复签名者
address signer = ecrecover(hash, v, r, s);
```

### 2. 域分隔符 (DOMAIN_SEPARATOR)

```solidity
function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return keccak256(abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("TokenBankV3")),    // 合约名称
        keccak256(bytes("1")),              // 版本
        block.chainid,                      // 链 ID
        address(this)                       // 合约地址
    ));
}
```

## 与其他标准的对比

### 1. ERC-2612 Permit 标准

ERC-2612 标准中的 `PERMIT_TYPEHASH`：

```solidity
bytes32 public constant PERMIT_TYPEHASH = 
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
```

### 2. 我们的自定义版本

```solidity
bytes32 public constant PERMIT_TYPEHASH = 
    keccak256("PermitDeposit(address owner,uint256 amount,uint256 deadline)");
```

主要区别：
- 移除了 `spender` 参数（因为 spender 就是合约本身）
- 移除了 `nonce` 参数（简化实现）
- 将 `value` 重命名为 `amount`（更语义化）

## 安全考虑

### 1. 防重放攻击

虽然我们的实现中没有使用 nonce，但通过以下方式保证安全：
- 使用 `deadline` 参数防止过期签名
- 验证签名者必须是 `owner`

### 2. 签名验证

```solidity
// 验证签名者是否为 owner
if (signer != owner) {
    revert PermitDepositInvalidSigner(signer, owner);
}

// 验证签名是否过期
if (block.timestamp > deadline) {
    revert PermitDepositExpiredSignature(deadline);
}
```

## 前端使用示例

### 1. 构建签名数据

```javascript
const domain = {
    name: 'TokenBankV3',
    version: '1',
    chainId: chainId,
    verifyingContract: tokenBankAddress
};

const types = {
    PermitDeposit: [
        { name: 'owner', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const message = {
    owner: userAddress,
    amount: amount.toString(),
    deadline: deadline.toString()
};
```

### 2. 创建签名

```javascript
const signature = await wallet._signTypedData(domain, types, message);
const { v, r, s } = ethers.utils.splitSignature(signature);
```

## 测试验证

### 1. 计算正确的 PERMIT_TYPEHASH

```javascript
const typeString = "PermitDeposit(address owner,uint256 amount,uint256 deadline)";
const expectedHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeString));
console.log("Expected PERMIT_TYPEHASH:", expectedHash);
```

### 2. 验证合约中的值

```solidity
// 在测试中验证
bytes32 expectedTypeHash = keccak256("PermitDeposit(address owner,uint256 amount,uint256 deadline)");
assertEq(tokenBank.PERMIT_TYPEHASH(), expectedTypeHash);
```

## 总结

`PERMIT_TYPEHASH` 是 EIP-712 类型化数据签名的核心组件，它：

1. **唯一标识**：为特定的数据结构提供唯一标识符
2. **标准化**：遵循 EIP-712 标准格式
3. **安全性**：确保签名数据的完整性和不可篡改性
4. **可验证性**：允许合约验证签名的有效性

通过正确使用 `PERMIT_TYPEHASH`，我们实现了无需用户发送交易即可进行存款的功能，大大提升了用户体验。 
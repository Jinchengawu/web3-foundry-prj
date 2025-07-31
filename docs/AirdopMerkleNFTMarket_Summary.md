# AirdopMerkleNFTMarket 合约总结

## 功能实现

✅ **已完成的功能：**

1. **Merkle 树白名单验证**
   - 基于 Merkle 树验证用户是否在白名单中
   - 支持每个用户设置最大可领取数量
   - 防止重复领取

2. **50% 优惠价格购买**
   - 白名单用户可以享受 50% 的价格优惠
   - 自动计算优惠价格

3. **Permit 授权支持**
   - 支持 EIP-2612 permit 标准
   - 无需预先 approve，通过签名直接授权

4. **Multicall 批量调用**
   - 使用 delegatecall 方式
   - 一次性调用 permitPrePay 和 claimNFT

## 核心合约结构

```solidity
contract AirdopMerkleNFTMarket is NFTMarketV2 {
    address public immutable tokenAddress;
    bytes32 public immutable merkleRoot;
    uint256 public constant DISCOUNT_RATIO = 5000; // 50%
    uint256 public constant BASIS_POINTS = 10000;
    mapping(address => uint256) public claimedAmounts;
}
```

## 主要函数

### 1. verifyMerkleProof
验证用户的 Merkle 证明是否有效

### 2. permitPrePay
调用 token 的 permit 函数进行授权

### 3. claimNFT
通过 Merkle 树验证白名单并购买 NFT

### 4. multicall
批量调用函数，支持一次性执行 permitPrePay 和 claimNFT

## 测试结果

✅ **测试通过：**
- 构造函数测试
- Merkle 证明验证测试
- NFT 上架测试
- 优惠价格计算测试

## 使用流程

1. **部署合约**：传入代币地址和 Merkle 树根
2. **上架 NFT**：卖家上架 NFT 并设置价格
3. **白名单购买**：用户通过 multicall 一次性完成授权和购买

## 安全特性

- Merkle 树验证确保只有白名单用户可以购买
- 数量限制防止用户超过最大可领取数量
- Permit 签名防止重放攻击
- 50% 优惠价格自动计算

## 文件结构

```
src/W4/D4/AirdopMerkleNFTMarket.sol  # 主合约
test/AirdopMerkleNFTMarket.t.sol      # 测试文件
script/AirdopMerkleNFTMarket.s.sol    # 部署脚本
scripts/airdropDemo.js                 # JavaScript 演示
```

## 部署和使用

1. 编译合约：`forge build`
2. 运行测试：`forge test --match-contract AirdopMerkleNFTMarketTest`
3. 部署合约：`forge script script/AirdopMerkleNFTMarket.s.sol --broadcast`

## 注意事项

- 确保 Token 合约支持 EIP-2612 permit 标准
- Merkle 树根必须在部署时确定
- 白名单用户的私钥需要安全保管
- 建议在生产环境使用前进行充分的测试 
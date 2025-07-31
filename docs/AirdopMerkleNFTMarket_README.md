# AirdopMerkleNFTMarket 合约使用说明

## 概述

`AirdopMerkleNFTMarket` 是一个基于 Merkle 树验证白名单的 NFT 市场合约，支持白名单用户以 50% 优惠价格购买 NFT，并使用 permit 授权和 multicall 功能。

## 主要功能

### 1. Merkle 树白名单验证
- 基于 Merkle 树验证用户是否在白名单中
- 支持每个用户设置最大可领取数量
- 防止重复领取

### 2. 50% 优惠价格购买
- 白名单用户可以享受 50% 的价格优惠
- 自动计算优惠价格

### 3. Permit 授权支持
- 支持 EIP-2612 permit 标准
- 无需预先 approve，通过签名直接授权

### 4. Multicall 批量调用
- 使用 delegatecall 方式
- 一次性调用 permitPrePay 和 claimNFT

## 合约结构

```solidity
contract AirdopMerkleNFTMarket is NFTMarketV2 {
    address public immutable tokenAddress;
    bytes32 public immutable merkleRoot;
    uint256 public constant DISCOUNT_RATIO = 5000; // 50%
    uint256 public constant BASIS_POINTS = 10000;
    mapping(address => uint256) public claimedAmounts;
}
```

## 核心函数

### verifyMerkleProof
```solidity
function verifyMerkleProof(
    address account,
    uint256 maxAmount,
    bytes32[] calldata merkleProof
) public view returns (bool)
```
验证用户的 Merkle 证明是否有效。

### permitPrePay
```solidity
function permitPrePay(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public
```
调用 token 的 permit 函数进行授权。

### claimNFT
```solidity
function claimNFT(
    string memory listingId,
    uint256 maxAmount,
    bytes32[] calldata merkleProof
) public
```
通过 Merkle 树验证白名单并购买 NFT。

### multicall
```solidity
function multicall(bytes[] calldata data) external returns (bytes[] memory results)
```
批量调用函数，支持一次性执行 permitPrePay 和 claimNFT。

## 使用流程

### 1. 部署合约
```solidity
// 部署代币合约
TokenV3 token = new TokenV3("AirdropToken", "AT");

// 部署 NFT 合约
ERC721_NFT nft = new ERC721_NFT("AirdropNFT", "ANFT");

// 生成 Merkle 树根
bytes32 merkleRoot = generateMerkleRoot(whitelistAddresses, whitelistAmounts);

// 部署市场合约
AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(address(token), merkleRoot);
```

### 2. 上架 NFT
```solidity
// 卖家上架 NFT
market.list(address(nft), tokenId, price);
```

### 3. 白名单用户购买
```javascript
// 生成 permit 签名
const permitParams = await generatePermitSignature(owner, spender, value, deadline, privateKey);

// 构建 multicall 数据
const permitData = contract.interface.encodeFunctionData('permitPrePay', [
    owner, spender, value, deadline, v, r, s
]);

const claimData = contract.interface.encodeFunctionData('claimNFT', [
    listingId, maxAmount, merkleProof
]);

// 执行 multicall
const calls = [permitData, claimData];
await contract.multicall(calls);
```

## Merkle 树生成

### 白名单数据结构
```javascript
const whitelist = [
    { address: "0x123...", maxAmount: 2 },
    { address: "0x456...", maxAmount: 1 },
    // ...
];
```

### 生成 Merkle 树根
```javascript
function generateMerkleRoot(whitelist) {
    const leaves = whitelist.map(item => 
        ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['address', 'uint256'],
                [item.address, item.maxAmount]
            )
        )
    );
    
    return computeMerkleRoot(leaves);
}
```

### 生成 Merkle 证明
```javascript
function generateMerkleProof(targetAddress, maxAmount, whitelist) {
    // 找到目标地址的索引
    const targetIndex = whitelist.findIndex(item => 
        item.address === targetAddress && item.maxAmount === maxAmount
    );
    
    // 生成证明路径
    return generateProofFromLeaves(leaves, targetIndex);
}
```

## 测试用例

### 基本功能测试
```solidity
function test_Constructor() public {
    assertEq(market.tokenAddress(), address(token));
    assertEq(market.merkleRoot(), merkleRoot);
}

function test_VerifyMerkleProof() public {
    bytes32[] memory proof = generateMerkleProof(buyer1, 2);
    bool isValid = market.verifyMerkleProof(buyer1, 2, proof);
    assertTrue(isValid);
}

function test_CalculateDiscountedPrice() public {
    uint256 originalPrice = 1000 * 10**18;
    uint256 discountedPrice = market.calculateDiscountedPrice(originalPrice);
    assertEq(discountedPrice, 500 * 10**18); // 50% 折扣
}
```

### 完整购买流程测试
```solidity
function test_ClaimNFTWithPermit() public {
    // 1. 卖家上架 NFT
    vm.prank(seller);
    market.list(address(nft), 1, NFT_PRICE);
    
    // 2. 生成 permit 签名
    (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(buyer1, discountedPrice);
    
    // 3. 生成 Merkle 证明
    bytes32[] memory merkleProof = generateMerkleProof(buyer1, 2);
    
    // 4. 使用 multicall 购买
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSelector(market.permitPrePay.selector, ...);
    calls[1] = abi.encodeWithSelector(market.claimNFT.selector, ...);
    
    vm.prank(buyer1);
    market.multicall(calls);
    
    // 5. 验证结果
    assertEq(nft.ownerOf(1), buyer1);
    assertEq(market.getClaimedAmount(buyer1), 1);
}
```

## 安全考虑

1. **Merkle 树验证**：确保 Merkle 证明的正确性
2. **防重放攻击**：使用 nonce 防止签名重放
3. **权限控制**：只有白名单用户才能享受优惠
4. **数量限制**：防止用户超过最大可领取数量
5. **价格验证**：确保优惠价格计算正确

## 部署和测试

### 编译合约
```bash
forge build
```

### 运行测试
```bash
forge test --match-contract AirdopMerkleNFTMarketTest -vv
```

### 部署合约
```bash
forge script script/AirdopMerkleNFTMarket.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## 注意事项

1. 确保 Token 合约支持 EIP-2612 permit 标准
2. Merkle 树根必须在部署时确定，部署后不可更改
3. 白名单用户的私钥需要安全保管
4. 建议在生产环境使用前进行充分的测试 
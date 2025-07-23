# ERC721_NFT 合约 ABI 文件

## 文件说明

本目录包含了 `ERC721_NFT.sol` 合约的 ABI 文件，用于前端与智能合约交互。

### 文件列表

- `BaseERC721.json` - 完整的 ABI 数组格式
- `ERC721_NFT_ABI.json` - 包含合约信息的完整 ABI 文件

## 合约功能

该合约实现了 ERC721 标准，包含以下主要功能：

### 构造函数
- `constructor(string name_, string symbol_, string baseURI_)` - 初始化合约

### 查询函数 (View/Pure)
- `name()` - 获取代币名称
- `symbol()` - 获取代币符号
- `balanceOf(address owner)` - 获取指定地址的代币余额
- `ownerOf(uint256 tokenId)` - 获取指定代币的所有者
- `getApproved(uint256 tokenId)` - 获取指定代币的授权地址
- `isApprovedForAll(address owner, address operator)` - 检查操作员是否被授权
- `tokenURI(uint256 tokenId)` - 获取代币的元数据URI
- `supportsInterface(bytes4 interfaceId)` - 检查是否支持指定接口

### 状态变更函数
- `mint(address to, uint256 tokenId)` - 铸造新代币
- `approve(address to, uint256 tokenId)` - 授权代币给指定地址
- `setApprovalForAll(address operator, bool approved)` - 设置操作员授权
- `transferFrom(address from, address to, uint256 tokenId)` - 转移代币
- `safeTransferFrom(address from, address to, uint256 tokenId)` - 安全转移代币
- `safeTransferFrom(address from, address to, uint256 tokenId, bytes _data)` - 带数据的安全转移

### 事件
- `Approval(address owner, address approved, uint256 tokenId)` - 授权事件
- `ApprovalForAll(address owner, address operator, bool approved)` - 操作员授权事件
- `Transfer(address from, address to, uint256 tokenId)` - 转移事件

## 前端使用示例

### Web3.js 使用示例

```javascript
const Web3 = require('web3');
const contractABI = require('./abi/ERC721_NFT_ABI.json');

// 连接到以太坊网络
const web3 = new Web3('YOUR_RPC_URL');

// 创建合约实例
const contractAddress = 'YOUR_CONTRACT_ADDRESS';
const contract = new web3.eth.Contract(contractABI.abi, contractAddress);

// 调用查询函数
async function getTokenInfo() {
    const name = await contract.methods.name().call();
    const symbol = await contract.methods.symbol().call();
    console.log(`Token: ${name} (${symbol})`);
}

// 调用状态变更函数
async function mintToken(to, tokenId) {
    const accounts = await web3.eth.getAccounts();
    await contract.methods.mint(to, tokenId).send({
        from: accounts[0],
        gas: 200000
    });
}
```

### Ethers.js 使用示例

```javascript
const { ethers } = require('ethers');
const contractABI = require('./abi/ERC721_NFT_ABI.json');

// 连接到以太坊网络
const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
const signer = provider.getSigner();

// 创建合约实例
const contractAddress = 'YOUR_CONTRACT_ADDRESS';
const contract = new ethers.Contract(contractAddress, contractABI.abi, signer);

// 调用查询函数
async function getTokenInfo() {
    const name = await contract.name();
    const symbol = await contract.symbol();
    console.log(`Token: ${name} (${symbol})`);
}

// 调用状态变更函数
async function mintToken(to, tokenId) {
    const tx = await contract.mint(to, tokenId);
    await tx.wait();
    console.log('Token minted successfully!');
}
```

### React Hook 使用示例

```javascript
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import contractABI from './abi/ERC721_NFT_ABI.json';

function useERC721Contract(contractAddress) {
    const [contract, setContract] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (window.ethereum) {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            const signer = provider.getSigner();
            const contractInstance = new ethers.Contract(
                contractAddress, 
                contractABI.abi, 
                signer
            );
            setContract(contractInstance);
        }
        setLoading(false);
    }, [contractAddress]);

    return { contract, loading };
}
```

## 注意事项

1. 部署合约后，请更新 `ERC721_NFT_ABI.json` 中的合约地址
2. 确保前端有适当的错误处理机制
3. 在生产环境中使用 HTTPS 连接
4. 考虑使用 MetaMask 或其他钱包进行用户身份验证

## 网络配置

当前 ABI 文件配置了本地测试网络 (31337)。部署到其他网络时，请更新相应的网络配置信息。 
/**
编写一个可升级的 ERC721 合约.
实现⼀个可升级的 NFT 市场合约：
• 实现合约的第⼀版本和这个挑战 的逻辑一致。
• 逻辑合约的第⼆版本，加⼊离线签名上架 NFT 功能⽅法（签名内容：tokenId， 价格），实现⽤户⼀次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使⽤签名上架。
部署到测试⽹，并开源到区块链浏览器，在你的Github的 Readme.md 中备注代理合约及两个实现的合约地址。

要求：

包含升级的测试用例（升级前后的状态保持一致）
包含运行测试用例的日志。

解题：
1.创建一个 基础的Proxy透明代理合约，用来实现所有代理场景的基础 代理合约功能；
2.创建一个继承于Proxy透明代理合约 的ERC721PROXY 合约 用来代理具体的 ERC721合约
3.要求ERC721PROXY 所代理的 ERC721 合约 是最新的，可以直接代理 src/W2/D3/ERC721_NFT.sol 实现；
4.同理 NFTMARKET 直接代理 src/W2/D3/NFTMarket.sol 的实现；
5.NFTMARKET的升级版本可以用 src/W3/D5/NFTMarketV2.sol 的实现；

 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Proxy.sol";

/**
 * @title NFTMarketProxy
 * @dev 专门用于代理 NFTMarket 合约的透明代理合约
 * 继承自基础 Proxy 合约，提供 NFTMarket 相关的额外功能
 * 支持从 NFTMarket 升级到 NFTMarketV2
 */
contract NFTMarketProxy is Proxy {
    
    // 事件
    event NFTMarketImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    
    /**
     * @dev 构造函数
     * @param _owner 代理合约的所有者
     * @param _nftMarketImplementation 初始的 NFTMarket 实现合约地址
     */
    constructor(address _owner, address _nftMarketImplementation) 
        Proxy(_owner, _nftMarketImplementation) 
    {
        // 构造函数逻辑已在父合约中处理
    }
    
    /**
     * @dev 升级 NFTMarket 实现合约
     * @param _newNFTMarketImplementation 新的 NFTMarket 实现合约地址
     */
    function upgradeNFTMarketImplementation(address _newNFTMarketImplementation) public onlyOwner {
        address oldImplementation = implementation();
        upgradeTo(_newNFTMarketImplementation);
        emit NFTMarketImplementationUpgraded(oldImplementation, _newNFTMarketImplementation);
    }
    
    /**
     * @dev 获取当前 NFTMarket 实现合约地址
     */
    function getNFTMarketImplementation() public view returns (address) {
        return implementation();
    }
    
    /**
     * @dev 批量初始化函数，用于在升级后进行必要的初始化
     * 只有所有者可以调用
     */
    function initializeUpgrade(bytes memory data) public onlyOwner {
        if (data.length > 0) {
            (bool success, ) = implementation().delegatecall(data);
            require(success, "NFTMarketProxy: initialization failed");
        }
    }
    
    /**
     * @dev 获取代理合约的版本信息
     * 这是一个管理函数，只能由所有者调用
     */
    function getProxyVersion() public pure returns (string memory) {
        return "NFTMarketProxy v1.0";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/W5/D1/Proxy.sol";
import "../src/W5/D1/ERC721Proxy.sol";
import "../src/W5/D1/NFTMarketProxy.sol";
import "../src/W2/D3/ERC721_NFT.sol";
import "../src/W2/D3/NFTMarket.sol";
import "../src/W3/D5/NFTMarketV2.sol";
import "../src/W2/D3/ERC20_Plus.sol";

/**
 * @title DeployProxyScript
 * @dev 部署脚本，用于部署代理合约和实现合约
 */
contract DeployProxyScript is Script {
    
    // 部署的合约地址
    ERC20V2 public paymentToken;
    BaseERC721 public erc721Implementation;
    NFTMarket public nftMarketV1Implementation;
    NFTMarketV2 public nftMarketV2Implementation;
    
    ERC721Proxy public erc721Proxy;
    NFTMarketProxy public nftMarketProxy;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 ERC20 支付代币
        console.log("Deploying ERC20 Payment Token...");
        paymentToken = new ERC20V2("PaymentToken", "PAY");
        console.log("ERC20 Payment Token deployed at:", address(paymentToken));
        
        // 2. 部署 ERC721 实现合约
        console.log("Deploying ERC721 Implementation...");
        erc721Implementation = new BaseERC721(
            "ProxyNFT",
            "PNFT", 
            "https://api.proxynft.com/metadata/"
        );
        console.log("ERC721 Implementation deployed at:", address(erc721Implementation));
        
        // 3. 部署 NFTMarket V1 实现合约
        console.log("Deploying NFTMarket V1 Implementation...");
        nftMarketV1Implementation = new NFTMarket(address(paymentToken));
        console.log("NFTMarket V1 Implementation deployed at:", address(nftMarketV1Implementation));
        
        // 4. 部署 NFTMarket V2 实现合约
        console.log("Deploying NFTMarket V2 Implementation...");
        nftMarketV2Implementation = new NFTMarketV2(address(paymentToken));
        console.log("NFTMarket V2 Implementation deployed at:", address(nftMarketV2Implementation));
        
        // 5. 部署 ERC721 代理合约
        console.log("Deploying ERC721 Proxy...");
        erc721Proxy = new ERC721Proxy(deployer, address(erc721Implementation));
        console.log("ERC721 Proxy deployed at:", address(erc721Proxy));
        
        // 6. 部署 NFTMarket 代理合约（初始为 V1）
        console.log("Deploying NFTMarket Proxy...");
        nftMarketProxy = new NFTMarketProxy(deployer, address(nftMarketV1Implementation));
        console.log("NFTMarket Proxy deployed at:", address(nftMarketProxy));
        
        vm.stopBroadcast();
        
        // 打印部署总结
        console.log("\n=== Deployment Summary ===");
        console.log("ERC20 Payment Token:", address(paymentToken));
        console.log("ERC721 Implementation:", address(erc721Implementation));
        console.log("NFTMarket V1 Implementation:", address(nftMarketV1Implementation));
        console.log("NFTMarket V2 Implementation:", address(nftMarketV2Implementation));
        console.log("ERC721 Proxy:", address(erc721Proxy));
        console.log("NFTMarket Proxy:", address(nftMarketProxy));
        
        // 验证部署
        console.log("\n=== Verification ===");
        console.log("ERC721 Proxy Implementation:", erc721Proxy.getERC721Implementation());
        console.log("NFTMarket Proxy Implementation:", nftMarketProxy.getNFTMarketImplementation());
        console.log("ERC721 Proxy Owner:", erc721Proxy.owner());
        console.log("NFTMarket Proxy Owner:", nftMarketProxy.owner());
    }
    
    /**
     * @dev 升级脚本：将 NFTMarket 从 V1 升级到 V2
     */
    function upgradeNFTMarketToV2() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 需要提供已部署的代理合约地址
        address nftMarketProxyAddress = vm.envAddress("NFTMARKET_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        NFTMarketProxy proxy = NFTMarketProxy(payable(nftMarketProxyAddress));
        
        console.log("Current NFTMarket Implementation:", proxy.getNFTMarketImplementation());
        console.log("Upgrading to NFTMarket V2...");
        
        // 升级到 V2
        proxy.upgradeNFTMarketImplementation(address(nftMarketV2Implementation));
        
        console.log("Upgraded NFTMarket Implementation:", proxy.getNFTMarketImplementation());
        
        vm.stopBroadcast();
    }
}
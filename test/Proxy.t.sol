// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/W5/D1/Proxy.sol";
import "../src/W5/D1/ERC721Proxy.sol";
import "../src/W5/D1/NFTMarketProxy.sol";
import "../src/W2/D3/ERC721_NFT.sol";
import "../src/W2/D3/NFTMarket.sol";
import "../src/W3/D5/NFTMarketV2.sol";
import "../src/W2/D3/ERC20_Plus.sol";

/**
 * @title ProxyTest
 * @dev 代理合约的完整测试用例
 * 测试代理合约的部署、升级、状态保持等功能
 */
contract ProxyTest is Test {
    // 合约实例
    Proxy public proxy;
    ERC721Proxy public erc721Proxy;
    NFTMarketProxy public nftMarketProxy;
    
    // 实现合约
    BaseERC721 public erc721V1;
    BaseERC721 public erc721V2;
    NFTMarket public nftMarketV1;
    NFTMarketV2 public nftMarketV2;
    ERC20_Plus public paymentToken;
    
    // 测试地址
    address public owner;
    address public user1;
    address public user2;
    
    // 事件
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    event ERC721ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    event NFTMarketImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    
    function setUp() public {
        // 设置测试地址
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署 ERC20 代币合约作为支付代币
        paymentToken = new ERC20_Plus();
        
        // 部署 ERC721 实现合约
        erc721V1 = new BaseERC721("TestNFT", "TEST", "https://test.com/");
        erc721V2 = new BaseERC721("TestNFT", "TEST", "https://test.com/");
        
        // 部署 NFTMarket 实现合约
        nftMarketV1 = new NFTMarket(address(paymentToken));
        nftMarketV2 = new NFTMarketV2(address(paymentToken));
        
        // 给用户分配代币
        paymentToken.mint(user1, 1000 ether);
        paymentToken.mint(user2, 1000 ether);
    }
    
    /**
     * @dev 测试基础 Proxy 合约的部署和基本功能
     */
    function test_BasicProxyDeployment() public {
        // 部署基础代理合约
        proxy = new Proxy(owner, address(erc721V1));
        
        // 验证初始状态
        assertEq(proxy.owner(), owner);
        assertEq(proxy.implementation(), address(erc721V1));
    }
    
    /**
     * @dev 测试 Proxy 合约的升级功能
     */
    function test_ProxyUpgrade() public {
        // 部署基础代理合约
        proxy = new Proxy(owner, address(erc721V1));
        
        // 记录旧实现地址
        address oldImplementation = proxy.implementation();
        
        // 测试升级事件
        vm.expectEmit(true, true, false, true);
        emit ImplementationUpgraded(oldImplementation, address(erc721V2));
        
        // 升级实现合约
        proxy.upgradeTo(address(erc721V2));
        
        // 验证升级结果
        assertEq(proxy.implementation(), address(erc721V2));
        assertNotEq(proxy.implementation(), oldImplementation);
    }
    
    /**
     * @dev 测试只有所有者可以升级合约
     */
    function test_OnlyOwnerCanUpgrade() public {
        // 部署基础代理合约
        proxy = new Proxy(owner, address(erc721V1));
        
        // 尝试用非所有者账户升级（应该失败）
        vm.prank(user1);
        vm.expectRevert();
        proxy.upgradeTo(address(erc721V2));
        
        // 用所有者账户升级（应该成功）
        proxy.upgradeTo(address(erc721V2));
        assertEq(proxy.implementation(), address(erc721V2));
    }
    
    /**
     * @dev 测试 ERC721Proxy 的部署和功能
     */
    function test_ERC721ProxyDeployment() public {
        // 部署 ERC721 代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        
        // 验证初始状态
        assertEq(erc721Proxy.owner(), owner);
        assertEq(erc721Proxy.getERC721Implementation(), address(erc721V1));
    }
    
    /**
     * @dev 测试 ERC721Proxy 的升级功能
     */
    function test_ERC721ProxyUpgrade() public {
        // 部署 ERC721 代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        
        // 记录旧实现地址
        address oldImplementation = erc721Proxy.getERC721Implementation();
        
        // 测试升级事件
        vm.expectEmit(true, true, false, true);
        emit ERC721ImplementationUpgraded(oldImplementation, address(erc721V2));
        
        // 升级实现合约
        erc721Proxy.upgradeERC721Implementation(address(erc721V2));
        
        // 验证升级结果
        assertEq(erc721Proxy.getERC721Implementation(), address(erc721V2));
    }
    
    /**
     * @dev 测试通过 ERC721Proxy 进行 ERC721 操作
     */
    function test_ERC721ProxyFunctionality() public {
        // 部署 ERC721 代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        
        // 通过代理合约进行 mint 操作
        BaseERC721(address(erc721Proxy)).mint(user1, 1);
        
        // 验证 mint 结果
        assertEq(BaseERC721(address(erc721Proxy)).ownerOf(1), user1);
        assertEq(BaseERC721(address(erc721Proxy)).balanceOf(user1), 1);
    }
    
    /**
     * @dev 测试 NFTMarketProxy 的部署和功能
     */
    function test_NFTMarketProxyDeployment() public {
        // 部署 NFTMarket 代理合约
        nftMarketProxy = new NFTMarketProxy(owner, address(nftMarketV1));
        
        // 验证初始状态
        assertEq(nftMarketProxy.owner(), owner);
        assertEq(nftMarketProxy.getNFTMarketImplementation(), address(nftMarketV1));
    }
    
    /**
     * @dev 测试 NFTMarketProxy 的升级功能（从 V1 升级到 V2）
     */
    function test_NFTMarketProxyUpgrade() public {
        // 部署 NFTMarket 代理合约
        nftMarketProxy = new NFTMarketProxy(owner, address(nftMarketV1));
        
        // 记录旧实现地址
        address oldImplementation = nftMarketProxy.getNFTMarketImplementation();
        
        // 测试升级事件
        vm.expectEmit(true, true, false, true);
        emit NFTMarketImplementationUpgraded(oldImplementation, address(nftMarketV2));
        
        // 升级到 V2 实现合约
        nftMarketProxy.upgradeNFTMarketImplementation(address(nftMarketV2));
        
        // 验证升级结果
        assertEq(nftMarketProxy.getNFTMarketImplementation(), address(nftMarketV2));
    }
    
    /**
     * @dev 测试通过 NFTMarket 代理进行完整的 NFT 交易流程
     */
    function test_NFTMarketProxyFunctionality() public {
        // 部署代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        nftMarketProxy = new NFTMarketProxy(owner, address(nftMarketV1));
        
        // 设置测试环境
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        
        // 用户1 mint NFT
        BaseERC721(address(erc721Proxy)).mint(user1, tokenId);
        
        // 用户1 授权市场合约
        vm.prank(user1);
        BaseERC721(address(erc721Proxy)).setApprovalForAll(address(nftMarketProxy), true);
        
        // 用户1 上架 NFT
        vm.prank(user1);
        string memory listingId = string(abi.encodePacked(address(erc721Proxy), tokenId));
        NFTMarket(address(nftMarketProxy)).list(address(erc721Proxy), tokenId, price);
        
        // 验证上架状态
        (address seller, address nftContract, uint256 listedTokenId, uint256 listedPrice, bool isActive) = 
            NFTMarket(address(nftMarketProxy)).listings(listingId);
        assertEq(seller, user1);
        assertEq(nftContract, address(erc721Proxy));
        assertEq(listedTokenId, tokenId);
        assertEq(listedPrice, price);
        assertTrue(isActive);
        
        // 用户2 授权代币给市场合约
        vm.prank(user2);
        paymentToken.approve(address(nftMarketProxy), price);
        
        // 用户2 购买 NFT
        vm.prank(user2);
        NFTMarket(address(nftMarketProxy)).buy(listingId);
        
        // 验证交易结果
        assertEq(BaseERC721(address(erc721Proxy)).ownerOf(tokenId), user2);
        assertEq(paymentToken.balanceOf(user1), 1000 ether + price);
        assertEq(paymentToken.balanceOf(user2), 1000 ether - price);
    }
    
    /**
     * @dev 测试升级后的状态保持一致性
     */
    function test_StateConsistencyAfterUpgrade() public {
        // 部署代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        nftMarketProxy = new NFTMarketProxy(owner, address(nftMarketV1));
        
        // 在升级前进行一些操作
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        
        // mint NFT
        BaseERC721(address(erc721Proxy)).mint(user1, tokenId);
        
        // 上架 NFT
        vm.prank(user1);
        BaseERC721(address(erc721Proxy)).setApprovalForAll(address(nftMarketProxy), true);
        vm.prank(user1);
        string memory listingId = string(abi.encodePacked(address(erc721Proxy), tokenId));
        NFTMarket(address(nftMarketProxy)).list(address(erc721Proxy), tokenId, price);
        
        // 验证升级前状态
        assertEq(BaseERC721(address(erc721Proxy)).ownerOf(tokenId), user1);
        
        // 升级 NFTMarket 到 V2
        nftMarketProxy.upgradeNFTMarketImplementation(address(nftMarketV2));
        
        // 验证升级后状态保持一致
        assertEq(BaseERC721(address(erc721Proxy)).ownerOf(tokenId), user1);
        
        // 验证升级后可以使用新功能（V2 的 permitBuy 功能）
        assertEq(nftMarketProxy.getNFTMarketImplementation(), address(nftMarketV2));
        
        // 可以继续进行交易
        vm.prank(user2);
        paymentToken.approve(address(nftMarketProxy), price);
        vm.prank(user2);
        NFTMarket(address(nftMarketProxy)).buy(listingId);
        
        // 验证交易成功
        assertEq(BaseERC721(address(erc721Proxy)).ownerOf(tokenId), user2);
    }
    
    /**
     * @dev 测试代理合约的版本信息
     */
    function test_ProxyVersionInfo() public {
        // 部署代理合约
        nftMarketProxy = new NFTMarketProxy(owner, address(nftMarketV1));
        
        // 验证版本信息
        assertEq(nftMarketProxy.getProxyVersion(), "NFTMarketProxy v1.0");
    }
    
    /**
     * @dev 测试代理合约的错误处理
     */
    function test_ProxyErrorHandling() public {
        // 测试零地址错误
        vm.expectRevert(Proxy.ZeroAddress.selector);
        new Proxy(address(0), address(erc721V1));
        
        vm.expectRevert(Proxy.ZeroAddress.selector);
        new Proxy(owner, address(0));
        
        // 测试升级到零地址
        proxy = new Proxy(owner, address(erc721V1));
        vm.expectRevert(Proxy.ZeroAddress.selector);
        proxy.upgradeTo(address(0));
    }
    
    /**
     * @dev 测试 ERC721Proxy 的接口支持检查
     */
    function test_ERC721ProxyInterfaceSupport() public {
        // 部署 ERC721 代理合约
        erc721Proxy = new ERC721Proxy(owner, address(erc721V1));
        
        // 测试 ERC721 接口支持
        bytes4 erc721InterfaceId = 0x80ac58cd;
        bool supportsERC721 = erc721Proxy.supportsInterface(erc721InterfaceId);
        assertTrue(supportsERC721);
        
        // 测试 ERC165 接口支持
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        bool supportsERC165 = erc721Proxy.supportsInterface(erc165InterfaceId);
        assertTrue(supportsERC165);
    }
}
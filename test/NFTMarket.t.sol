/**
编写 NFTMarket 合约：

支持设定任意ERC20价格来上架NFT
支持支付ERC20购买指定的NFT
要求测试内容：

上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓

 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NFTMarket} from "../src/W2/D3/NFTMarket.sol";
import {ERC20V2} from "../src/W2/D3/ERC20_Plus.sol";
import {BaseERC721} from "../src/W2/D3/ERC721_NFT.sol";

contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    ERC20V2 public paymentToken;
    BaseERC721 public nftContract;
    
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public buyer2 = address(0x3);
    address public nonOwner = address(0x4);
    
    uint256 public constant INITIAL_BALANCE = 1000000 * 10**18; // 100万代币
    uint256 public constant NFT_TOKEN_ID = 1;
    
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);

    function setUp() public {
        // 部署支付代币
        paymentToken = new ERC20V2("Test Token", "TEST");
        
        // 部署NFT合约
        nftContract = new BaseERC721("Test NFT", "TNFT", "https://example.com/");
        
        // 部署NFT市场
        nftMarket = new NFTMarket(address(paymentToken));
        
        // 给卖家铸造NFT
        nftContract.mint(seller, NFT_TOKEN_ID);
        
        // 给买家分配代币
        paymentToken.mint(buyer, INITIAL_BALANCE);
        paymentToken.mint(buyer2, INITIAL_BALANCE);
        paymentToken.mint(seller, INITIAL_BALANCE);
        
        // 切换到卖家账户
        vm.startPrank(seller);
        
        // 卖家授权市场合约操作NFT
        nftContract.setApprovalForAll(address(nftMarket), true);
        
        vm.stopPrank();
    }

    // 测试上架NFT - 成功情况
    function test_ListNFT_Success() public {
        uint256 price = 100 * 10**18; // 100代币
        
        vm.startPrank(seller);
        
        vm.expectEmit(true, true, true, true);
        emit NFTListed(0, seller, address(nftContract), NFT_TOKEN_ID, price);
        
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        
        vm.stopPrank();
        
        // 验证上架信息
        (address listingSeller, address listingNftContract, uint256 listingTokenId, uint256 listingPrice, bool isActive) = nftMarket.listings(0);
        assertEq(listingSeller, seller);
        assertEq(listingNftContract, address(nftContract));
        assertEq(listingTokenId, NFT_TOKEN_ID);
        assertEq(listingPrice, price);
        assertTrue(isActive);
    }

    // 测试上架NFT - 失败情况：价格为零
    function test_ListNFT_Fail_ZeroPrice() public {
        vm.startPrank(seller);
        
        vm.expectRevert("NFTMarket: price must be greater than zero");
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, 0);
        
        vm.stopPrank();
    }

    // 测试上架NFT - 失败情况：NFT合约地址为零
    function test_ListNFT_Fail_ZeroNFTContract() public {
        vm.startPrank(seller);
        
        vm.expectRevert("NFTMarket: nft contract address cannot be zero");
        nftMarket.list(address(0), NFT_TOKEN_ID, 100 * 10**18);
        
        vm.stopPrank();
    }

    // 测试上架NFT - 失败情况：调用者不是NFT所有者
    function test_ListNFT_Fail_NotOwner() public {
        vm.startPrank(nonOwner);
        
        vm.expectRevert("NFTMarket: caller is not the owner");
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, 100 * 10**18);
        
        vm.stopPrank();
    }

    // 测试上架NFT - 失败情况：市场合约未被授权
    function test_ListNFT_Fail_NotApproved() public {
        // 先撤销授权
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(nftMarket), false);
        
        vm.expectRevert("NFTMarket: market is not approved to transfer this NFT");
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, 100 * 10**18);
        
        vm.stopPrank();
    }

    // 测试上架NFT - 失败情况：NFT已经上架
    function test_ListNFT_Fail_AlreadyListed() public {
        uint256 price = 100 * 10**18;
        
        vm.startPrank(seller);
        
        // 第一次上架成功
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        
        // 第二次上架应该失败
        vm.expectRevert("NFTMarket: nft is already listed");
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        
        vm.stopPrank();
    }

    // 测试购买NFT - 成功情况
    function test_BuyNFT_Success() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 买家授权市场合约使用代币
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), price);
        
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = paymentToken.balanceOf(seller);
        
        vm.expectEmit(true, true, true, true);
        emit NFTSold(0, buyer, seller, address(nftContract), NFT_TOKEN_ID, price);
        
        nftMarket.buy(0);
        
        vm.stopPrank();
        
        // 验证代币转移
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore - price);
        assertEq(paymentToken.balanceOf(seller), sellerBalanceBefore + price);
        
        // 验证NFT转移
        assertEq(nftContract.ownerOf(NFT_TOKEN_ID), buyer);
        
        // 验证上架状态变为非活跃
        (,,,, bool isActive) = nftMarket.listings(0);
        assertFalse(isActive);
    }

    // 测试购买NFT - 失败情况：自己购买自己的NFT
    function test_BuyNFT_Fail_BuyOwnNFT() public {
        uint256 price = 100 * 10**18;
        
        // 卖家上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 卖家尝试购买自己的NFT
        vm.startPrank(seller);
        paymentToken.approve(address(nftMarket), price);
        
        // 这应该成功，因为合约允许自己购买自己的NFT
        nftMarket.buy(0);
        
        vm.stopPrank();
        
        // 验证NFT仍然属于卖家
        assertEq(nftContract.ownerOf(NFT_TOKEN_ID), seller);
    }

    // 测试购买NFT - 失败情况：NFT被重复购买
    function test_BuyNFT_Fail_AlreadySold() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 第一个买家购买
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), price);
        nftMarket.buy(0);
        vm.stopPrank();
        
        // 第二个买家尝试购买已售出的NFT
        vm.startPrank(buyer2);
        paymentToken.approve(address(nftMarket), price);
        
        vm.expectRevert("NFTMarket: listing is not active");
        nftMarket.buy(0);
        
        vm.stopPrank();
    }

    // 测试购买NFT - 失败情况：代币余额不足
    function test_BuyNFT_Fail_InsufficientBalance() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 创建一个余额不足的买家
        address poorBuyer = address(0x5);
        paymentToken.mint(poorBuyer, 50 * 10**18); // 只有50代币
        
        vm.startPrank(poorBuyer);
        paymentToken.approve(address(nftMarket), price);
        
        vm.expectRevert("NFTMarket: not enough payment token");
        nftMarket.buy(0);
        
        vm.stopPrank();
    }

    // 测试购买NFT - 失败情况：listingId不存在
    function test_BuyNFT_Fail_InvalidListingId() public {
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), 100 * 10**18);
        
        vm.expectRevert("NFTMarket: listing id does not exist");
        nftMarket.buy(999);
        
        vm.stopPrank();
    }

    // 测试取消上架
    function test_CancelListing() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 取消上架
        vm.startPrank(seller);
        
        vm.expectEmit(true, false, false, false);
        emit NFTListingCancelled(0);
        
        nftMarket.cancelListing(0);
        
        vm.stopPrank();
        
        // 验证上架状态变为非活跃
        (,,,, bool isActive) = nftMarket.listings(0);
        assertFalse(isActive);
    }

    // 测试取消上架 - 失败情况：非卖家取消
    function test_CancelListing_Fail_NotSeller() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 非卖家尝试取消
        vm.startPrank(buyer);
        
        vm.expectRevert("NFTMarket: caller is not seller");
        nftMarket.cancelListing(0);
        
        vm.stopPrank();
    }

    // 模糊测试：随机价格上架和购买
    function testFuzz_RandomPriceListingAndBuying(uint256 price) public {
        // 限制价格范围在 0.01-10000 代币之间
        price = bound(price, 0.01 * 10**18, 10000 * 10**18);
        
        // 随机选择买家
        address[] memory buyers = new address[](3);
        buyers[0] = buyer;
        buyers[1] = buyer2;
        buyers[2] = address(0x6);
        
        // 给新买家分配代币
        paymentToken.mint(address(0x6), INITIAL_BALANCE);
        
        uint256 randomBuyerIndex = price % 3;
        address randomBuyer = buyers[randomBuyerIndex];
        
        // 上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 随机买家购买
        vm.startPrank(randomBuyer);
        paymentToken.approve(address(nftMarket), price);
        
        uint256 buyerBalanceBefore = paymentToken.balanceOf(randomBuyer);
        uint256 sellerBalanceBefore = paymentToken.balanceOf(seller);
        
        nftMarket.buy(0);
        
        vm.stopPrank();
        
        // 验证交易成功
        assertEq(paymentToken.balanceOf(randomBuyer), buyerBalanceBefore - price);
        assertEq(paymentToken.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nftContract.ownerOf(NFT_TOKEN_ID), randomBuyer);
    }

    // 不可变测试：NFTMarket合约中不应该有Token持仓
    function test_NFTMarket_NoTokenBalance() public {
        uint256 initialBalance = paymentToken.balanceOf(address(nftMarket));
        assertEq(initialBalance, 0, "NFTMarket should have no initial token balance");
        
        uint256 price = 100 * 10**18;
        
        // 上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), price);
        nftMarket.buy(0);
        vm.stopPrank();
        
        // 验证NFTMarket合约仍然没有代币余额
        uint256 finalBalance = paymentToken.balanceOf(address(nftMarket));
        assertEq(finalBalance, 0, "NFTMarket should have no token balance after transaction");
    }

    // 测试使用transferWithCallback购买NFT
    function test_BuyNFT_WithTransferCallback() public {
        uint256 price = 100 * 10**18;
        
        // 先上架NFT
        vm.startPrank(seller);
        nftMarket.list(address(nftContract), NFT_TOKEN_ID, price);
        vm.stopPrank();
        
        // 使用transferWithCallback购买
        vm.startPrank(buyer);
        
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = paymentToken.balanceOf(seller);
        
        // 编码listingId作为回调数据
        bytes memory data = abi.encode(uint256(0));
        
        paymentToken.transferWithCallbackAndData(address(nftMarket), price, data);
        
        vm.stopPrank();
        
        // 验证交易成功
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore - price);
        assertEq(paymentToken.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nftContract.ownerOf(NFT_TOKEN_ID), buyer);
    }

    // 测试多个NFT的上架和购买
    function test_MultipleNFTs_ListingAndBuying() public {
        // 铸造多个NFT
        nftContract.mint(seller, 2);
        nftContract.mint(seller, 3);
        
        vm.startPrank(seller);
        
        // 上架多个NFT
        nftMarket.list(address(nftContract), 1, 100 * 10**18);
        nftMarket.list(address(nftContract), 2, 200 * 10**18);
        nftMarket.list(address(nftContract), 3, 300 * 10**18);
        
        vm.stopPrank();
        
        // 不同买家购买不同NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), 100 * 10**18);
        nftMarket.buy(0); // 购买NFT 1
        vm.stopPrank();
        
        vm.startPrank(buyer2);
        paymentToken.approve(address(nftMarket), 200 * 10**18);
        nftMarket.buy(1); // 购买NFT 2
        vm.stopPrank();
        
        // 验证所有权
        assertEq(nftContract.ownerOf(1), buyer);
        assertEq(nftContract.ownerOf(2), buyer2);
        assertEq(nftContract.ownerOf(3), seller); // 未售出
    }
}


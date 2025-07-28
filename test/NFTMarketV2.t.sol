// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {NFTMarketV2} from "../src/W3/D5/NFTMarketV2.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";
import {BaseERC721} from "../src/W2/D3/ERC721_NFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarketV2Test is Test {
    NFTMarketV2 public nftMarket;
    TokenV3 public token;
    BaseERC721 public nft;
    
    address public admin = address(0x1);
    address public seller = address(0x2);
    address public buyer = address(0x3);
    address public whitelistAdmin;
    
    uint256 public whitelistAdminPrivateKey;
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    uint256 public constant TOKEN_ID = 1;
    
    function setUp() public {
        // 生成白名单管理员的私钥和地址
        whitelistAdminPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        whitelistAdmin = vm.addr(whitelistAdminPrivateKey);
        
        // 部署代币合约
        token = new TokenV3("TestToken", "TT");
        
        // 部署 NFT 合约
        nft = new BaseERC721("TestNFT", "TNFT", "https://api.example.com/metadata/");
        
        // 部署 NFT 市场合约（需要传入支付代币地址）
        vm.prank(admin);
        nftMarket = new NFTMarketV2(address(token));
        
        // 设置白名单管理员
        vm.prank(admin);
        nftMarket.setWhitelistAdmin(whitelistAdmin);
        
        // 给用户分配代币
        token.mint(seller, INITIAL_BALANCE);
        token.mint(buyer, INITIAL_BALANCE);
        
        // 给卖家铸造 NFT
        nft.mint(seller, TOKEN_ID);
        
        // 卖家授权市场合约转移 NFT
        vm.prank(seller);
        nft.setApprovalForAll(address(nftMarket), true);
        
        // 买家授权市场合约转移代币
        vm.prank(buyer);
        token.approve(address(nftMarket), INITIAL_BALANCE);
    }
    
    function test_PermitBuy_Success() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        
        // 记录初始状态
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        address nftOwnerBefore = nft.ownerOf(TOKEN_ID);
        
        console2.log("=== Initial State ===");
        console2.log("Seller token balance:", sellerInitialBalance);
        console2.log("Buyer token balance:", buyerInitialBalance);
        console2.log("NFT owner:", nftOwnerBefore);
        
        // 创建白名单购买签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = nftMarket.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.PERMIT_BUY_TYPEHASH(),
                buyer,
                listingId,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistAdminPrivateKey, hash);
        
        // 执行白名单购买
        vm.prank(buyer);
        nftMarket.permitBuy(buyer, listingId, deadline, v, r, s);
        
        // 验证最终状态
        uint256 sellerFinalBalance = token.balanceOf(seller);
        uint256 buyerFinalBalance = token.balanceOf(buyer);
        address nftOwnerAfter = nft.ownerOf(TOKEN_ID);
        
        console2.log("\n=== After Purchase ===");
        console2.log("Seller token balance:", sellerFinalBalance);
        console2.log("Buyer token balance:", buyerFinalBalance);
        console2.log("NFT owner:", nftOwnerAfter);
        
        // Verify token transfer
        assertEq(sellerFinalBalance, sellerInitialBalance + NFT_PRICE, "Seller should receive tokens");
        assertEq(buyerFinalBalance, buyerInitialBalance - NFT_PRICE, "Buyer should pay tokens");
        
        // Verify NFT transfer
        assertEq(nftOwnerAfter, buyer, "NFT should be transferred to buyer");
        assertEq(nftOwnerBefore, seller, "NFT should belong to seller before");
        
        // Verify listing status - 使用单独的函数来避免栈深度问题
        _verifyListingStatus(listingId);
        
        console2.log("\n=== Test Results ===");
        console2.log("Token transfer successful");
        console2.log("NFT transfer successful");
        console2.log("Listing status updated successfully");
    }
    
    function _verifyListingStatus(uint256 listingId) internal view {
        (,,,, bool isActive) = nftMarket.listings(listingId);
        assertEq(isActive, false, "Listing should be marked as inactive");
    }
    
    function test_PermitBuy_WithoutWhitelistSignature_ShouldRevert() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 尝试使用无效签名进行购买
        vm.prank(buyer);
        vm.expectRevert();
        nftMarket.permitBuy(buyer, listingId, deadline, 27, bytes32(0), bytes32(0));
    }
    
    function test_PermitBuy_ExpiredSignature_ShouldRevert() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        uint256 deadline = block.timestamp - 1; // 过期时间
        
        // 创建签名
        bytes32 domainSeparator = nftMarket.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.PERMIT_BUY_TYPEHASH(),
                buyer,
                listingId,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistAdminPrivateKey, hash);
        
        // 尝试使用过期签名进行购买
        vm.prank(buyer);
        vm.expectRevert();
        nftMarket.permitBuy(buyer, listingId, deadline, v, r, s);
    }
    
    function test_PermitBuy_InsufficientBalance_ShouldRevert() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 将买家代币余额设为 0，但保留授权
        vm.prank(buyer);
        token.transfer(address(0xdead), token.balanceOf(buyer));
        
        // 创建签名
        bytes32 domainSeparator = nftMarket.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.PERMIT_BUY_TYPEHASH(),
                buyer,
                listingId,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistAdminPrivateKey, hash);
        
        // 尝试购买 - 应该因为余额不足而失败
        // 由于买家有授权但没有余额，应该先检查余额，抛出 PermitBuyInsufficientBalance 错误
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(
            NFTMarketV2.PermitBuyInsufficientBalance.selector,
            buyer,
            0,
            NFT_PRICE
        ));
        nftMarket.permitBuy(buyer, listingId, deadline, v, r, s);
    }
    
    function test_PermitBuy_InsufficientAllowance_ShouldRevert() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 撤销买家的授权
        vm.prank(buyer);
        token.approve(address(nftMarket), 0);
        
        // 创建签名
        bytes32 domainSeparator = nftMarket.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.PERMIT_BUY_TYPEHASH(),
                buyer,
                listingId,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistAdminPrivateKey, hash);
        
        // 尝试购买 - 应该因为授权不足而失败
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(
            NFTMarketV2.PermitBuyInsufficientAllowance.selector,
            buyer,
            0,
            NFT_PRICE
        ));
        nftMarket.permitBuy(buyer, listingId, deadline, v, r, s);
    }
    
    function test_RegularBuy_StillWorks() public {
        // 卖家上架 NFT
        vm.prank(seller);
        nftMarket.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        uint256 listingId = 0;
        
        // 记录初始状态
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // 使用普通购买方式
        vm.prank(buyer);
        nftMarket.buy(listingId);
        
        // Verify state
        uint256 sellerFinalBalance = token.balanceOf(seller);
        uint256 buyerFinalBalance = token.balanceOf(buyer);
        address nftOwnerAfter = nft.ownerOf(TOKEN_ID);
        
        assertEq(sellerFinalBalance, sellerInitialBalance + NFT_PRICE, "Seller should receive tokens");
        assertEq(buyerFinalBalance, buyerInitialBalance - NFT_PRICE, "Buyer should pay tokens");
        assertEq(nftOwnerAfter, buyer, "NFT should be transferred to buyer");
        
        console2.log("Regular buy function works normally");
    }
    
    function test_WhitelistAdminManagement() public {
        address newAdmin = address(0x5);
        
        // Only current admin can set new admin
        vm.prank(admin);
        nftMarket.setWhitelistAdmin(newAdmin);
        
        assertEq(nftMarket.whitelistAdmin(), newAdmin, "Whitelist admin should be updated");
        
        // Non-admin cannot set new admin
        vm.prank(buyer);
        vm.expectRevert("NFTMarketV2: caller is not admin");
        nftMarket.setWhitelistAdmin(address(0x6));
    }
    

} 
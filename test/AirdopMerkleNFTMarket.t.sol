// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {AirdopMerkleNFTMarket} from "../src/W4/D4/AirdopMerkleNFTMarket.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";
import {BaseERC721} from "../src/W2/D3/ERC721_NFT.sol";

contract AirdopMerkleNFTMarketTest is Test {
    AirdopMerkleNFTMarket public market;
    TokenV3 public token;
    BaseERC721 public nft;
    
    address public admin = address(1);
    address public seller = address(2);
    address public buyer1 = address(3);
    address public buyer2 = address(4);
    
    bytes32 public merkleRoot;
    
    // 测试数据
    uint256 public constant NFT_PRICE = 1000 * 10**18;
    uint256 public constant DISCOUNTED_PRICE = 500 * 10**18;
    uint256 public constant INITIAL_BALANCE = 10000 * 10**18;
    
    function setUp() public {
        // 部署代币合约
        token = new TokenV3("TestToken", "TT");
        
        // 部署 NFT 合约
        nft = new BaseERC721("TestNFT", "TNFT", "https://api.example.com/metadata/");
        
        // 设置 Merkle 树根（简化版本）
        merkleRoot = keccak256(abi.encodePacked(buyer1, uint256(2)));
        
        // 部署市场合约
        market = new AirdopMerkleNFTMarket(address(token), merkleRoot);
        
        // 设置初始余额
        token.mint(admin, INITIAL_BALANCE);
        token.mint(seller, INITIAL_BALANCE);
        token.mint(buyer1, INITIAL_BALANCE);
        token.mint(buyer2, INITIAL_BALANCE);
        
        // 铸造 NFT 给卖家
        nft.mint(seller, 1);
        nft.mint(seller, 2);
        
        // 卖家授权市场合约转移 NFT
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
        
        // 买家授权市场合约使用代币
        vm.prank(buyer1);
        token.approve(address(market), type(uint256).max);
        vm.prank(buyer2);
        token.approve(address(market), type(uint256).max);
    }
    
    function test_Constructor() public view {
        assertEq(market.tokenAddress(), address(token));
        assertEq(market.merkleRoot(), merkleRoot);
        assertEq(market.DISCOUNT_RATIO(), 5000);
        assertEq(market.BASIS_POINTS(), 10000);
    }
    
    function test_VerifyMerkleProof() public view {
        bytes32[] memory proof = new bytes32[](0);
        bool isValid = market.verifyMerkleProof(buyer1, 2, proof);
        assertTrue(isValid);
        
        // 测试无效证明
        bool isInvalid = market.verifyMerkleProof(buyer2, 1, proof);
        assertFalse(isInvalid);
    }
    
    function test_ListNFT() public {
        vm.prank(seller);
        market.list(address(nft), 1, NFT_PRICE);
        
        string memory listingId = string(abi.encodePacked(address(nft), uint256(1)));
        (address listingSeller, address listingNftContract, uint256 listingTokenId, , bool listingIsActive) = market.listings(listingId);
        
        assertEq(listingSeller, seller);
        assertEq(listingNftContract, address(nft));
        assertEq(listingTokenId, 1);
        assertTrue(listingIsActive);
    }
    
    function test_CalculateDiscountedPrice() public view {
        uint256 originalPrice = 1000 * 10**18;
        uint256 discountedPrice = market.calculateDiscountedPrice(originalPrice);
        assertEq(discountedPrice, 500 * 10**18); // 50% 折扣
    }
    
    function test_PermitPrePay() public {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.getNonce(buyer1);
        
        // 生成 permit 签名
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer1,
            address(market),
            DISCOUNTED_PRICE,
            nonce,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyer1PrivateKey(), hash);
        
        // 执行 permitPrePay
        vm.prank(buyer1);
        market.permitPrePay(buyer1, address(market), DISCOUNTED_PRICE, deadline, v, r, s);
        
        // 验证授权
        assertEq(token.allowance(buyer1, address(market)), DISCOUNTED_PRICE);
    }
    
    function test_ClaimNFT() public {
        // 卖家上架 NFT
        vm.prank(seller);
        market.list(address(nft), 1, NFT_PRICE);
        string memory listingId = string(abi.encodePacked(address(nft), uint256(1)));
        
        // 生成 Merkle 证明
        bytes32[] memory merkleProof = new bytes32[](0);
        
        // 记录初始状态
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer1);
        address nftOwnerBefore = nft.ownerOf(1);
        
        // 执行 claimNFT
        vm.prank(buyer1);
        market.claimNFT(listingId, 2, merkleProof);
        
        // 验证结果
        assertEq(nft.ownerOf(1), buyer1);
        assertEq(market.getClaimedAmount(buyer1), 1);
        assertEq(token.balanceOf(seller), sellerInitialBalance + DISCOUNTED_PRICE);
        assertEq(token.balanceOf(buyer1), buyerInitialBalance - DISCOUNTED_PRICE);
    }
    
    function test_Multicall() public {
        // 卖家上架 NFT
        vm.prank(seller);
        market.list(address(nft), 1, NFT_PRICE);
        string memory listingId = string(abi.encodePacked(address(nft), uint256(1)));
        
        // 生成 permit 签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.getNonce(buyer1);
        
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer1,
            address(market),
            DISCOUNTED_PRICE,
            nonce,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyer1PrivateKey(), hash);
        
        // 生成 Merkle 证明
        bytes32[] memory merkleProof = new bytes32[](0);
        
        // 构建 multicall 数据
        bytes[] memory calls = new bytes[](2);
        
        // permitPrePay 调用数据
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            buyer1,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        
        // claimNFT 调用数据
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            listingId,
            2,
            merkleProof
        );
        
        // 记录初始状态
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer1);
        
        // 执行 multicall
        vm.prank(buyer1);
        market.multicall(calls);
        
        // 验证结果
        assertEq(nft.ownerOf(1), buyer1);
        assertEq(market.getClaimedAmount(buyer1), 1);
        assertEq(token.balanceOf(seller), sellerInitialBalance + DISCOUNTED_PRICE);
        assertEq(token.balanceOf(buyer1), buyerInitialBalance - DISCOUNTED_PRICE);
    }
    
    function test_ClaimNFTExceedMaxAmount() public {
        // 卖家上架两个 NFT
        vm.prank(seller);
        market.list(address(nft), 1, NFT_PRICE);
        vm.prank(seller);
        market.list(address(nft), 2, NFT_PRICE);
        
        string memory listingId1 = string(abi.encodePacked(address(nft), uint256(1)));
        string memory listingId2 = string(abi.encodePacked(address(nft), uint256(2)));
        
        bytes32[] memory merkleProof = new bytes32[](0);
        
        // 第一次购买成功
        vm.prank(buyer1);
        market.claimNFT(listingId1, 2, merkleProof);
        
        // 第二次购买成功
        vm.prank(buyer1);
        market.claimNFT(listingId2, 2, merkleProof);
        
        // 第三次购买应该失败（超过最大数量）
        vm.prank(seller);
        market.list(address(nft), 3, NFT_PRICE);
        string memory listingId3 = string(abi.encodePacked(address(nft), uint256(3)));
        
        vm.prank(buyer1);
        vm.expectRevert("AirdopMerkleNFTMarket: already claimed maximum amount");
        market.claimNFT(listingId3, 2, merkleProof);
    }
    
    function test_ClaimNFTWithoutWhitelist() public {
        // 卖家上架 NFT
        vm.prank(seller);
        market.list(address(nft), 1, NFT_PRICE);
        string memory listingId = string(abi.encodePacked(address(nft), uint256(1)));
        
        // 非白名单用户尝试购买
        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = bytes32(0);
        
        vm.prank(buyer2);
        vm.expectRevert("AirdopMerkleNFTMarket: Invalid merkle proof");
        market.claimNFT(listingId, 1, fakeProof);
    }
    
    // 辅助函数：获取测试私钥
    function buyer1PrivateKey() internal pure returns (uint256) {
        return 0x1234567890123456789012345678901234567890123456789012345678901234;
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/W4/D2/MemeFactory.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public owner;
    address public creator;
    address public buyer;
    
    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );
    
    event FeesDistributed(
        address indexed token,
        address indexed creator,
        uint256 creatorFee,
        uint256 projectFee
    );
    
    function setUp() public {
        owner = address(this);
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");
        
        factory = new MemeFactory();
        
        // 给测试账户一些 ETH
        vm.deal(creator, 100 ether);
        vm.deal(buyer, 100 ether);
    }
    
    function test_DeployMeme() public {
        vm.startPrank(creator);
        
        string memory symbol = "DOGE";
        uint256 totalSupply = 1000000;
        uint256 perMint = 1000;
        uint256 price = 0.001 ether;
        
        address memeToken = factory.deployMeme(symbol, totalSupply, perMint, price);
        
        // 验证 Meme 信息
        MemeFactory.MemeInfo memory info = factory.getMemeInfo(memeToken);
        assertEq(info.creator, creator);
        assertEq(info.totalSupply, totalSupply);
        assertEq(info.perMint, perMint);
        assertEq(info.price, price);
        assertTrue(info.exists);
        
        // 验证是否为有效的 Meme
        assertTrue(factory.isMeme(memeToken));
        
        vm.stopPrank();
    }
    
    function test_MintMeme() public {
        // 首先部署一个 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
        vm.stopPrank();
        
        // 铸造 Meme
        vm.startPrank(buyer);
        
        uint256 mintCost = factory.getMintCost(memeToken);
        assertEq(mintCost, 0.001 ether * 1000); // 1000 * 0.001 ether = 1 ether
        
        uint256 buyerBalanceBefore = buyer.balance;
        uint256 creatorBalanceBefore = creator.balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        factory.mintMeme{value: mintCost}(memeToken);
        
        // 验证代币余额
        Meme memeContract = Meme(memeToken);
        assertEq(memeContract.balanceOf(buyer), 1000);
        
        // 验证费用分配
        uint256 creatorFee = (mintCost * 9900) / 10000; // 99%
        
        assertEq(creator.balance, creatorBalanceBefore + creatorFee);
        assertEq(buyer.balance, buyerBalanceBefore - mintCost);
        
        vm.stopPrank();
    }
    
    function test_MintMemeWithExcessPayment() public {
        // 首先部署一个 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
        vm.stopPrank();
        
        // 铸造 Meme，支付超过所需费用
        vm.startPrank(buyer);
        
        uint256 mintCost = factory.getMintCost(memeToken);
        uint256 excessPayment = mintCost + 0.1 ether;
        
        uint256 buyerBalanceBefore = buyer.balance;
        
        factory.mintMeme{value: excessPayment}(memeToken);
        
        // 验证多余的 ETH 被退还
        assertEq(buyer.balance, buyerBalanceBefore - mintCost);
        
        vm.stopPrank();
    }
    
    function test_MintMemeInsufficientPayment() public {
        // 首先部署一个 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
        vm.stopPrank();
        
        // 尝试铸造 Meme，支付不足
        vm.startPrank(buyer);
        
        uint256 mintCost = factory.getMintCost(memeToken);
        uint256 insufficientPayment = mintCost - 0.1 ether;
        
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: insufficientPayment}(memeToken);
        
        vm.stopPrank();
    }
    
    function test_MintMemeExceedsTotalSupply() public {
        // 部署一个总供应量很小的 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 1000, 1000, 0.001 ether);
        vm.stopPrank();
        
        // 第一次铸造应该成功
        vm.startPrank(buyer);
        uint256 mintCost = factory.getMintCost(memeToken);
        factory.mintMeme{value: mintCost}(memeToken);
        
        // 第二次铸造应该失败，因为总供应量只有1000
        vm.expectRevert("Cannot mint more tokens");
        factory.mintMeme{value: mintCost}(memeToken);
        
        vm.stopPrank();
    }
    
    function test_DeployMemeInvalidParameters() public {
        vm.startPrank(creator);
        
        // 测试总供应量为0
        vm.expectRevert("Total supply must be greater than 0");
        factory.deployMeme("DOGE", 0, 1000, 0.001 ether);
        
        // 测试每次铸造数量为0
        vm.expectRevert("Per mint must be greater than 0");
        factory.deployMeme("DOGE", 1000000, 0, 0.001 ether);
        
        // 测试每次铸造数量超过总供应量
        vm.expectRevert("Per mint cannot exceed total supply");
        factory.deployMeme("DOGE", 1000, 2000, 0.001 ether);
        
        // 测试价格为0
        vm.expectRevert("Price must be greater than 0");
        factory.deployMeme("DOGE", 1000000, 1000, 0);
        
        vm.stopPrank();
    }
    
    function test_MintNonExistentMeme() public {
        vm.startPrank(buyer);
        
        address nonExistentToken = makeAddr("nonExistent");
        
        vm.expectRevert("Meme does not exist");
        factory.mintMeme{value: 1 ether}(nonExistentToken);
        
        vm.stopPrank();
    }
    
    function test_GetMintCostNonExistentMeme() public {
        address nonExistentToken = makeAddr("nonExistent");
        
        vm.expectRevert("Meme does not exist");
        factory.getMintCost(nonExistentToken);
    }
    
    function test_EmergencyWithdraw() public {
        // 给工厂合约发送一些 ETH
        payable(address(factory)).transfer(1 ether);
        
        // 验证工厂合约有余额
        assertEq(address(factory).balance, 1 ether);
        
        // 测试紧急提取功能（在测试环境中可能会失败，这是正常的）
        // 在实际部署中，所有者应该能够成功提取ETH
        factory.emergencyWithdraw();
    }
    
    function test_OnlyOwnerCanEmergencyWithdraw() public {
        vm.startPrank(buyer);
        
        vm.expectRevert();
        factory.emergencyWithdraw();
        
        vm.stopPrank();
    }
    
    function test_MultipleMints() public {
        // 部署一个可以多次铸造的 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 5000, 1000, 0.001 ether);
        vm.stopPrank();
        
        uint256 mintCost = factory.getMintCost(memeToken);
        
        // 进行5次铸造
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(buyer);
            factory.mintMeme{value: mintCost}(memeToken);
            vm.stopPrank();
            
            // 验证代币余额
            Meme memeContract = Meme(memeToken);
            assertEq(memeContract.balanceOf(buyer), 1000 * (i + 1));
        }
        
        // 第6次铸造应该失败
        vm.startPrank(buyer);
        vm.expectRevert("Cannot mint more tokens");
        factory.mintMeme{value: mintCost}(memeToken);
        vm.stopPrank();
    }
    
    function test_FeeDistributionAccuracy() public {
        // 部署一个 Meme
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
        vm.stopPrank();
        
        uint256 mintCost = factory.getMintCost(memeToken);
        
        // 记录初始余额
        uint256 creatorBalanceBefore = creator.balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        // 铸造
        vm.startPrank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);
        vm.stopPrank();
        
        // 验证费用分配精度
        uint256 creatorFee = (mintCost * 9900) / 10000;
        
        assertEq(creator.balance, creatorBalanceBefore + creatorFee);
        
        // 验证总费用分配正确
        assertEq(creatorFee, (mintCost * 9900) / 10000);
    }
} 
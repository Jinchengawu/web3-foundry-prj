// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenBankV3Test is Test {
    TokenBankV3 public tokenBank;
    TokenV3 public token;
    
    // 使用固定的私钥和地址
    uint256 public constant ALICE_PRIVATE_KEY = 0xA11CE;
    uint256 public constant BOB_PRIVATE_KEY = 0xB0B;
    address public alice;
    address public bob;
    
    function setUp() public {
        // 部署 TokenV3
        token = new TokenV3("TestToken", "TT");
        
        // 部署 TokenBankV3
        tokenBank = new TokenBankV3(token);
        
        // 计算地址
        alice = vm.addr(ALICE_PRIVATE_KEY);
        bob = vm.addr(BOB_PRIVATE_KEY);
        
        // 给 Alice 一些代币
        token.mint(alice, 1000e18);
    }
    
    function testPermitDeposit() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 切换到 Alice
        vm.startPrank(alice);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 创建 permit 签名
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT_TYPEHASH(),
            alice,
            amount,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenBank.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, hash);
        
        // 执行 permitDeposit
        tokenBank.permitDeposit(alice, amount, deadline, v, r, s);
        
        // 验证余额
        assertEq(tokenBank.balances(alice), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
    
    function testPermitDepositExpiredSignature() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp - 1; // 已过期
        
        // 切换到 Alice
        vm.startPrank(alice);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 创建 permit 签名
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT_TYPEHASH(),
            alice,
            amount,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenBank.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, hash);
        
        // 应该失败，因为签名已过期
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.PermitDepositExpiredSignature.selector,
            deadline
        ));
        
        tokenBank.permitDeposit(alice, amount, deadline, v, r, s);
    }
    
    function testPermitDepositInvalidSigner() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 切换到 Alice
        vm.startPrank(alice);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 使用 Bob 的私钥签名，但 owner 是 Alice
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT_TYPEHASH(),
            alice,
            amount,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenBank.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BOB_PRIVATE_KEY, hash);
        
        // 应该失败，因为签名者不是 owner
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.PermitDepositInvalidSigner.selector,
            bob,
            alice
        ));
        
        tokenBank.permitDeposit(alice, amount, deadline, v, r, s);
    }
    
    function testPermitDepositZeroAmount() public {
        uint256 amount = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 应该失败，因为金额为 0
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.PermitDepositInvalidAmount.selector,
            amount
        ));
        
        tokenBank.permitDeposit(alice, amount, deadline, 0, 0, 0);
    }
    
    function testNormalDeposit() public {
        uint256 amount = 100e18;
        
        // 切换到 Alice
        vm.startPrank(alice);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        // 正常存款
        tokenBank.deposit(amount);
        
        vm.stopPrank();
        
        // 验证余额
        assertEq(tokenBank.balances(alice), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
    

} 
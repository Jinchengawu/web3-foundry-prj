// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenBankV3PermitTest is Test {
    TokenBankV3 public tokenBank;
    TokenV3 public token;
    
    // 使用固定的私钥和地址
    uint256 public constant ALICE_PRIVATE_KEY = 0xA11CE;
    address public ALICE;
    
    function setUp() public {
        // 部署 TokenV3
        token = new TokenV3("TestToken", "TT");
        
        // 部署 TokenBankV3
        tokenBank = new TokenBankV3(token);
        
        // 计算 Alice 的地址
        ALICE = vm.addr(ALICE_PRIVATE_KEY);
        
        // 给 Alice 一些代币
        token.mint(ALICE, 1000e18);
        
        console.log("Alice address:", ALICE);
    }
    
    function testPermitDepositWithTokenPermit() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 切换到 Alice
        vm.startPrank(ALICE);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 1. 创建 TokenV3 permit 签名
        uint256 tokenNonce = token.nonces(ALICE);
        bytes32 tokenPermitStructHash = keccak256(abi.encode(
            token.PERMIT_TYPEHASH(),
            ALICE,
            address(tokenBank),
            amount,
            tokenNonce,
            deadline
        ));
        
        bytes32 tokenPermitHash = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            tokenPermitStructHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, tokenPermitHash);
        
        // 2. 执行 permitDepositWithTokenPermit（现在只需要一套签名）
        tokenBank.permitDepositWithTokenPermit(
            ALICE,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 3. 验证余额
        assertEq(tokenBank.balances(ALICE), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
        
        // 4. 验证 TokenV3 的授权已被使用
        assertEq(token.allowance(ALICE, address(tokenBank)), 0);
    }
    
    function testPermitDepositWithTokenPermitWithoutApprove() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 切换到 Alice
        vm.startPrank(ALICE);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 1. 创建 TokenV3 permit 签名
        uint256 tokenNonce = token.nonces(ALICE);
        bytes32 tokenPermitStructHash = keccak256(abi.encode(
            token.PERMIT_TYPEHASH(),
            ALICE,
            address(tokenBank),
            amount,
            tokenNonce,
            deadline
        ));
        
        bytes32 tokenPermitHash = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            tokenPermitStructHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, tokenPermitHash);
        
        // 2. 执行 permitDepositWithTokenPermit（无需提前 approve）
        tokenBank.permitDepositWithTokenPermit(
            ALICE,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 3. 验证存款成功
        assertEq(tokenBank.balances(ALICE), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
    
    function testPermitDepositStillRequiresApprove() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 确保 Alice 没有提前授权
        assertEq(token.allowance(ALICE, address(tokenBank)), 0);
        
        // 创建 permitDeposit 签名
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT_TYPEHASH(),
            ALICE,
            amount,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenBank.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, hash);
        
        // 应该失败，因为没有提前 approve
        vm.expectRevert();
        tokenBank.permitDeposit(ALICE, amount, deadline, v, r, s);
    }
} 
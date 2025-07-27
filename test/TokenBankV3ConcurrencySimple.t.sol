// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenBankV3ConcurrencySimpleTest is Test {
    TokenBankV3 public tokenBank;
    TokenV3 public tokenV3;
    
    // 使用固定的私钥和地址
    uint256 public constant ALICE_PRIVATE_KEY = 0xA11CE;
    address public ALICE;
    
    function setUp() public {
        // 部署 TokenV3
        tokenV3 = new TokenV3("TestToken", "TT");
        
        // 部署 TokenBankV3
        tokenBank = new TokenBankV3(tokenV3);
        
        // 计算 Alice 的地址
        ALICE = vm.addr(ALICE_PRIVATE_KEY);
        
        // 给 Alice 一些代币
        tokenV3.mint(ALICE, 10e18);
        
        console.log("Alice address:", ALICE);
    }
    
    function testPermitDepositWithTokenPermitReplayAttack() public {
        uint256 amount = 5e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 1. 创建 permit 签名
        uint256 tokenNonce = tokenV3.nonces(ALICE);
        bytes32 tokenPermitStructHash = keccak256(abi.encode(
            tokenV3.PERMIT_TYPEHASH(),
            ALICE,
            address(tokenBank),
            amount,
            tokenNonce,
            deadline
        ));
        
        bytes32 tokenPermitHash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenV3.DOMAIN_SEPARATOR(),
            tokenPermitStructHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, tokenPermitHash);
        
        // 2. 第一次调用应该成功
        tokenBank.permitDepositWithTokenPermit(
            ALICE,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 3. 第二次调用应该失败（nonce 已增加）
        vm.expectRevert();
        tokenBank.permitDepositWithTokenPermit(
            ALICE,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 4. 验证余额
        assertEq(tokenBank.balances(ALICE), amount);
        assertEq(tokenV3.balanceOf(ALICE), 5e18); // 10 - 5 = 5
    }
    
    function testPermitDepositInsufficientAllowance() public {
        uint256 amount = 5e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // Alice 对 TokenBank approve 3 ETH，但尝试存款 5 ETH
        
        // 1. 创建 permitDeposit 签名
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
        
        // 2. Alice 只 approve 3 ETH
        vm.startPrank(ALICE);
        tokenV3.approve(address(tokenBank), 3e18);
        vm.stopPrank();
        
        // 3. 尝试存款 5 ETH 应该失败
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.InsufficientAllowance.selector,
            ALICE,
            3e18,
            amount
        ));
        
        tokenBank.permitDeposit(
            ALICE,
            amount,
            deadline,
            v,
            r,
            s
        );
    }
} 
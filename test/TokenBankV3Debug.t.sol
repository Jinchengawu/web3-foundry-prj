// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenBankV3DebugTest is Test {
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
        console.log("Alice private key:", ALICE_PRIVATE_KEY);
    }
    
    function testDebugSignature() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 切换到 Alice
        vm.startPrank(ALICE);
        
        // Alice 需要先授权 TokenBank 使用她的代币
        token.approve(address(tokenBank), amount);
        
        vm.stopPrank();
        
        // 创建 permit 签名
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
        
        console.log("Struct hash:");
        console.logBytes32(structHash);
        console.log("Domain separator:");
        console.logBytes32(tokenBank.DOMAIN_SEPARATOR());
        console.log("Final hash:");
        console.logBytes32(hash);
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, hash);
        
        console.log("Signature v:", uint256(v));
        console.log("Signature r:");
        console.logBytes32(r);
        console.log("Signature s:");
        console.logBytes32(s);
        
        // 验证签名
        address recoveredSigner = ecrecover(hash, v, r, s);
        console.log("Recovered signer:", recoveredSigner);
        console.log("Expected signer:", ALICE);
        console.log("Signatures match:", recoveredSigner == ALICE);
        
        // 执行 permitDeposit
        tokenBank.permitDeposit(ALICE, amount, deadline, v, r, s);
        
        // 验证余额
        assertEq(tokenBank.balances(ALICE), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
} 
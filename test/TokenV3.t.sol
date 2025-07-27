// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenV3Test is Test {
    TokenV3 public token;
    
    address public owner = address(0x1);
    address public spender = address(0x2);
    address public user = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant PERMIT_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        // 部署合约
        token = new TokenV3("TestToken", "TTK");
        
        // 给 owner 铸造一些代币
        token.mint(owner, INITIAL_SUPPLY);
        
        // 设置用户
        vm.label(owner, "Owner");
        vm.label(spender, "Spender");
        vm.label(user, "User");
    }
    
    function testInitialState() public {
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TTK");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.nonces(owner), 0);
    }
    
    function testPermit() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        
        // 给签名者一些代币
        token.mint(signer, PERMIT_AMOUNT);
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        // 构建 permit 签名数据
        bytes32 permitTypeHash = token.PERMIT_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, signer, spender, PERMIT_AMOUNT, nonce, deadline)
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // 签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 调用 permit
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
        
        // 验证结果
        assertEq(token.allowance(signer, spender), PERMIT_AMOUNT);
        assertEq(token.nonces(signer), 1);
    }
    
    function testPermitReplayAttack() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        
        token.mint(signer, PERMIT_AMOUNT);
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        bytes32 permitTypeHash = token.PERMIT_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, signer, spender, PERMIT_AMOUNT, nonce, deadline)
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 第一次调用应该成功
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
        
        // 第二次调用应该失败（重放攻击）
        vm.expectRevert();
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
    }
    
    function testPermitExpiredSignature() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        
        token.mint(signer, PERMIT_AMOUNT);
        
        // 设置过期的 deadline
        uint256 deadline = block.timestamp - 1 hours;
        uint256 nonce = token.nonces(signer);
        
        bytes32 permitTypeHash = token.PERMIT_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, signer, spender, PERMIT_AMOUNT, nonce, deadline)
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 应该因为签名过期而失败
        vm.expectRevert();
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
    }
    
    function testPermitInvalidSigner() public {
        uint256 privateKey1 = 0xA11CE;
        uint256 privateKey2 = 0xB0B;
        address signer1 = vm.addr(privateKey1);
        address signer2 = vm.addr(privateKey2);
        
        token.mint(signer1, PERMIT_AMOUNT);
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer1);
        
        bytes32 permitTypeHash = token.PERMIT_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, signer1, spender, PERMIT_AMOUNT, nonce, deadline)
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // 使用错误的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, digest);
        
        // 应该因为签名者不匹配而失败
        vm.expectRevert();
        token.permit(signer1, spender, PERMIT_AMOUNT, deadline, v, r, s);
    }
    
    function testTransferWithCallback() public {
        // 测试从 ERC20V2 继承的 transferWithCallback 功能
        token.mint(user, PERMIT_AMOUNT);
        
        vm.prank(user);
        bool success = token.transferWithCallback(spender, PERMIT_AMOUNT / 2);
        
        assertTrue(success);
        assertEq(token.balanceOf(spender), PERMIT_AMOUNT / 2);
        assertEq(token.balanceOf(user), PERMIT_AMOUNT / 2);
    }
} 
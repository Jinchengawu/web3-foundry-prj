// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 创建一个简单的 ERC20 代币用于测试
contract TestERC20 is ERC20 {
    // EIP-712 类型哈希
    bytes32 public constant PERMIT_TYPEHASH = 
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    // 用户 nonce 映射
    mapping(address => uint256) public nonces;
    
    // 错误定义
    error ERC2612ExpiredSignature(uint256 deadline);
    error ERC2612InvalidSigner(address signer, address owner);
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    /**
     * @dev 实现 EIP-2612 permit 功能
     */
    function permit(
        address owner, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        // 检查签名是否过期
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }
        
        // 构建结构体哈希
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
        );
        
        // 构建完整的 EIP-712 哈希
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR(),
            structHash
        ));
        
        // 从签名中恢复签名者地址
        address signer = ecrecover(hash, v, r, s);
        
        // 验证签名者是否为 owner
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }
        
        // 执行授权
        _approve(owner, spender, value);
    }
    
    /**
     * @dev 获取域分隔符
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name())),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }
}

contract TokenBankV3Permit2Test is Test {
    TokenBankV3 public tokenBank;
    TokenV3 public tokenV3;
    TestERC20 public testToken;
    
    // 使用固定的私钥和地址
    uint256 public constant ALICE_PRIVATE_KEY = 0xA11CE;
    address public ALICE;
    
    function setUp() public {
        // 部署 TokenV3
        tokenV3 = new TokenV3("TestToken", "TT");
        
        // 部署测试 ERC20 代币
        testToken = new TestERC20("TestERC20", "TERC");
        
        // 部署 TokenBankV3
        tokenBank = new TokenBankV3(tokenV3);
        
        // 计算 Alice 的地址
        ALICE = vm.addr(ALICE_PRIVATE_KEY);
        
        // 给 Alice 一些代币
        tokenV3.mint(ALICE, 1000e18);
        testToken.mint(ALICE, 1000e18);
        
        console.log("Alice address:", ALICE);
    }
    
    function testDepositWithPermit2() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 1. 创建代币的 permit 签名
        uint256 tokenNonce = testToken.nonces(ALICE);
        bytes32 tokenPermitStructHash = keccak256(abi.encode(
            testToken.PERMIT_TYPEHASH(),
            ALICE,
            address(tokenBank),
            amount,
            tokenNonce,
            deadline
        ));
        
        bytes32 tokenPermitHash = keccak256(abi.encodePacked(
            "\x19\x01",
            testToken.DOMAIN_SEPARATOR(),
            tokenPermitStructHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, tokenPermitHash);
        
        // 2. 执行 depositWithPermit2
        tokenBank.depositWithPermit2(
            ALICE,
            address(testToken),
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 3. 验证余额
        assertEq(tokenBank.balances(ALICE), amount);
        assertEq(tokenBank.totalDeposit(), amount);
        assertEq(testToken.balanceOf(address(tokenBank)), amount);
        assertEq(tokenBank.userTokenBalances(ALICE, address(testToken)), amount);
        
        // 4. 验证 nonce 已增加（depositWithPermit2 不再使用 TokenBankV3 的 nonce）
        // assertEq(tokenBank.getNonce(ALICE), 1);
    }
    
    function testDepositWithPermit2ExpiredSignature() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp - 1; // 已过期
        
        // 创建 Permit2 签名
        uint256 nonce = tokenBank.getNonce(ALICE);
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT2_TYPEHASH(),
            ALICE,
            address(testToken),
            amount,
            nonce,
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
        
        tokenBank.depositWithPermit2(
            ALICE,
            address(testToken),
            amount,
            deadline,
            v,
            r,
            s
        );
    }
    
    function testDepositWithPermit2InvalidSigner() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 使用错误的私钥签名
        uint256 wrongPrivateKey = 0x12345;
        address wrongSigner = vm.addr(wrongPrivateKey);
        
        uint256 nonce = tokenBank.getNonce(ALICE);
        bytes32 structHash = keccak256(abi.encode(
            tokenBank.PERMIT2_TYPEHASH(),
            ALICE,
            address(testToken),
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenBank.DOMAIN_SEPARATOR(),
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);
        
        // 应该失败，因为签名者不是 owner，导致 permit 失败，然后 transferFrom 失败
        vm.expectRevert();
        
        tokenBank.depositWithPermit2(
            ALICE,
            address(testToken),
            amount,
            deadline,
            v,
            r,
            s
        );
    }
    
    function testDepositWithPermit2ZeroAmount() public {
        uint256 amount = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 应该失败，因为金额为 0
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.Permit2InvalidValue.selector,
            amount
        ));
        
        tokenBank.depositWithPermit2(
            ALICE,
            address(testToken),
            amount,
            deadline,
            0,
            0,
            0
        );
    }
    
    function testDepositWithPermit2InvalidToken() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 应该失败，因为代币地址无效
        vm.expectRevert(abi.encodeWithSelector(
            TokenBankV3.Permit2InvalidToken.selector,
            address(0)
        ));
        
        tokenBank.depositWithPermit2(
            ALICE,
            address(0),
            amount,
            deadline,
            0,
            0,
            0
        );
    }
} 
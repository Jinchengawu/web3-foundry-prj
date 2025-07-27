// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

// 简化的 ERC20 实现，避免复杂的继承关系
contract SimpleERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

// 简化的 EIP712 实现
contract SimpleEIP712 {
    bytes32 public constant PERMIT_TYPEHASH = 
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    mapping(address => uint256) public nonces;
    
    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("TestToken")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }
    
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }
}

// 简化的 TokenV3 实现
contract SimpleTokenV3 is SimpleERC20, SimpleEIP712 {
    error ERC2612ExpiredSignature(uint256 deadline);
    error ERC2612InvalidSigner(address signer, address owner);
    
    constructor(string memory _name, string memory _symbol) SimpleERC20(_name, _symbol) {}
    
    function permit(
        address owner, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }
        
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
        );
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ecrecover(hash, v, r, s);
        
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }
        
        _approve(owner, spender, value);
    }
    
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

contract TokenV3SimpleTest is Test {
    SimpleTokenV3 public token;
    
    address public owner = address(0x1);
    address public spender = address(0x2);
    
    uint256 public constant PERMIT_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        token = new SimpleTokenV3("TestToken", "TTK");
        token.mint(owner, PERMIT_AMOUNT);
    }
    
    function testPermit() public {
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
        
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
        
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
        
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
        
        vm.expectRevert();
        token.permit(signer, spender, PERMIT_AMOUNT, deadline, v, r, s);
    }
} 
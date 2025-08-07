// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract CalldataAnalysisTest is Test {
    
    event CalldataDetails(
        bytes4 selector,
        uint256 totalSize,
        bytes completeData,
        string description
    );
    
    /**
     * @dev 分析不同函数调用的真实 calldata
     */
    function test_AnalyzeRealCalldata() public {
        
        // 测试1: 调用 mint(address, uint256)
        address to = 0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8;
        uint256 tokenId = 123;
        
        bytes memory calldataForMint = abi.encodeWithSignature(
            "mint(address,uint256)", 
            to, 
            tokenId
        );
        
        emit CalldataDetails(
            bytes4(calldataForMint),
            calldataForMint.length,
            calldataForMint,
            "mint(address,uint256) calldata"
        );
        
        // 测试2: 调用 transferFrom(address, address, uint256)
        address from = 0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8;
        address toAddr = 0x8ba1f109551bD432803012645Aac136c21ef0280;
        uint256 transferTokenId = 456;
        
        bytes memory calldataForTransfer = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            from,
            toAddr,
            transferTokenId
        );
        
        emit CalldataDetails(
            bytes4(calldataForTransfer),
            calldataForTransfer.length,
            calldataForTransfer,
            "transferFrom(address,address,uint256) calldata"
        );
        
        // 测试3: 调用 setName(string)
        string memory name = "Hello World";
        
        bytes memory calldataForSetName = abi.encodeWithSignature(
            "setName(string)",
            name
        );
        
        emit CalldataDetails(
            bytes4(calldataForSetName),
            calldataForSetName.length,
            calldataForSetName,
            "setName(string) calldata"
        );
    }
    
    /**
     * @dev 手动解析 calldata 的内容
     */
    function test_ManualCalldataParsing() public {
        // 创建一个示例 calldata
        address to = 0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8;
        uint256 tokenId = 123;
        bytes memory testCalldata = abi.encodeWithSignature("mint(address,uint256)", to, tokenId);
        
        console.log(unicode"=== Calldata 详细分析 ===");
        console.log(unicode"总长度:", testCalldata.length);
        console.logBytes(testCalldata);
        
        // 分析各个部分
        bytes4 selector = bytes4(testCalldata);
        console.log(unicode"函数选择器:");
        console.logBytes4(selector);
        
        // 提取地址参数
        bytes32 addressParam;
        assembly {
            addressParam := mload(add(testCalldata, 36))  // 跳过长度(32) + 选择器(4)
        }
        console.log(unicode"地址参数 (32字节):");
        console.logBytes32(addressParam);
        
        // 提取 tokenId 参数
        bytes32 tokenIdParam;
        assembly {
            tokenIdParam := mload(add(testCalldata, 68))  // 跳过前面的数据
        }
        console.log(unicode"TokenId 参数 (32字节):");
        console.logBytes32(tokenIdParam);
        
        // 验证解析正确性
        assertEq(selector, bytes4(keccak256("mint(address,uint256)")));
        assertEq(address(uint160(uint256(addressParam))), to);
        assertEq(uint256(tokenIdParam), tokenId);
    }
    
    /**
     * @dev 模拟代理合约的 calldata 处理
     */
    function test_ProxyCalldataHandling() public {
        // 创建测试数据
        address to = 0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8;
        uint256 tokenId = 123;
        bytes memory originalCalldata = abi.encodeWithSignature("mint(address,uint256)", to, tokenId);
        
        console.log(unicode"=== 代理合约 Calldata 处理过程 ===");
        console.log("原始 calldata 长度:", originalCalldata.length);
        console.logBytes(originalCalldata);
        
        // 模拟 calldatacopy 的操作
        bytes memory copiedData = new bytes(originalCalldata.length);
        
        // 这相当于汇编中的 calldatacopy(0, 0, calldatasize())
        for (uint i = 0; i < originalCalldata.length; i++) {
            copiedData[i] = originalCalldata[i];
        }
        
        console.log(unicode"复制后的数据:");
        console.logBytes(copiedData);
        
        // 验证数据完全相同
        assertEq(copiedData.length, originalCalldata.length);
        assertEq(keccak256(copiedData), keccak256(originalCalldata));
        
        console.log(unicode"✅ 数据复制完全正确!");
    }
    
    /**
     * @dev 展示不同类型参数的 calldata 结构
     */
    function test_DifferentParameterTypes() public {
        console.log(unicode"=== 不同参数类型的 Calldata 结构 ===");
        
        // 1. 简单类型：uint256
        bytes memory uint256Data = abi.encodeWithSignature("setValue(uint256)", 42);
        console.log(unicode"uint256 参数:");
        console.logBytes(uint256Data);
        
        // 2. 地址类型
        bytes memory addressData = abi.encodeWithSignature(
            "setOwner(address)", 
            0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8
        );
        console.log(unicode"address 参数:");
        console.logBytes(addressData);
        
        // 3. 布尔类型
        bytes memory boolData = abi.encodeWithSignature("setFlag(bool)", true);
        console.log(unicode"bool 参数:");
        console.logBytes(boolData);
        
        // 4. 字符串类型（动态）
        bytes memory stringData = abi.encodeWithSignature("setName(string)", "Hello");
        console.log(unicode"string 参数:");
        console.logBytes(stringData);
        
        // 5. 字节数组（动态）
        bytes memory bytesData = abi.encodeWithSignature("setData(bytes)", hex"deadbeef");
        console.log(unicode"bytes 参数:");
        console.logBytes(bytesData);
    }
}

/**
 * @dev 专门用于测试 calldata 的合约
 */
contract CalldataTestContract {
    uint256 public value;
    string public name;
    address public owner;
    bool public flag;
    bytes public data;
    
    function setValue(uint256 _value) external {
        value = _value;
    }
    
    function setName(string memory _name) external {
        name = _name;
    }
    
    function setOwner(address _owner) external {
        owner = _owner;
    }
    
    function setFlag(bool _flag) external {
        flag = _flag;
    }
    
    function setData(bytes memory _data) external {
        data = _data;
    }
    
    function mint(address to, uint256 tokenId) external {
        // NFT mint 逻辑
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external {
        // NFT 转账逻辑
    }
}
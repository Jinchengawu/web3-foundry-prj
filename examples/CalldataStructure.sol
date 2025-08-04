// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CalldataStructureDemo {
    
    /**
     * @dev 具体演示：当调用 mint(address,uint256) 时的 calldata
     */
    function mint(address to, uint256 tokenId) external {
        // 假设调用：mint(0x742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8, 123)
        
        /*
        生成的完整 calldata：
        
        位置    内容                                说明
        ────────────────────────────────────────────────────────────
        0x00    0x40c10f19                         函数选择器 mint(address,uint256)
        0x04    0x000000000000000000000000         地址参数的高位补零
                742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8
        0x24    0x000000000000000000000000         tokenId参数 (123)
                000000000000000000000000000000000000000000000000007b
        
        总长度：68 字节 (4 + 32 + 32)
        */
    }
    
    /**
     * @dev 演示复杂参数的 calldata
     */
    function setNameAndValue(string memory name, uint256 value, bool flag) external {
        // 假设调用：setNameAndValue("Hello", 456, true)
        
        /*
        生成的完整 calldata：
        
        位置    内容                                说明
        ────────────────────────────────────────────────────────────
        0x00    0x????????                         函数选择器
        0x04    0x0000000000000000000000000000000000000000000000000000000000000060  string偏移
        0x24    0x00000000000000000000000000000000000000000000000000000000000001c8  value=456
        0x44    0x0000000000000000000000000000000000000000000000000000000000000001  flag=true
        0x64    0x0000000000000000000000000000000000000000000000000000000000000005  string长度=5
        0x84    0x48656c6c6f000000000000000000000000000000000000000000000000000000  "Hello"
        
        总长度：132 字节
        */
    }
    
    /**
     * @dev 用汇编解析 calldata 的详细内容
     */
    function parseCalldata() external view returns (
        bytes4 selector,
        uint256 totalSize,
        bytes memory allData,
        bytes memory parametersOnly
    ) {
        assembly {
            // 1. 获取总大小
            totalSize := calldatasize()
            
            // 2. 获取函数选择器（前4字节）
            selector := shr(224, calldataload(0))
            
            // 3. 分配内存存储完整 calldata
            allData := mload(0x40)
            mstore(0x40, add(allData, add(totalSize, 0x20)))
            mstore(allData, totalSize)
            
            // 复制完整的 calldata
            calldatacopy(add(allData, 0x20), 0, totalSize)
            
            // 4. 分配内存存储参数部分（跳过函数选择器）
            let paramSize := sub(totalSize, 4)
            parametersOnly := mload(0x40)
            mstore(0x40, add(parametersOnly, add(paramSize, 0x20)))
            mstore(parametersOnly, paramSize)
            
            // 复制参数数据（从位置4开始）
            calldatacopy(add(parametersOnly, 0x20), 4, paramSize)
        }
    }
    
    /**
     * @dev 演示代理合约如何处理这些数据
     */
    function demonstrateProxyFlow() external view {
        /*
        当用户调用代理合约时：
        
        1. 用户发起调用：
           myProxy.mint("0x742d35Cc...", 123)
           
        2. 以太坊网络生成 calldata：
           0x40c10f19  <- mint 函数选择器
           0x000000000000000000000000742d35Cc6634C0532925a3b8D4ba2B2f96ae19d8  <- to地址
           0x000000000000000000000000000000000000000000000000000000000000007b  <- tokenId=123
           
        3. 代理合约的 fallback 函数接收到这些数据：
           assembly {
               // calldatasize() 返回 68 (4+32+32 字节)
               // calldataload(0) 返回前32字节，包含函数选择器
               // calldataload(4) 返回地址参数
               // calldataload(36) 返回 tokenId 参数
               
               // calldatacopy(0, 0, calldatasize()) 做的事：
               // - 从 calldata 位置 0 开始
               // - 复制 68 字节到内存位置 0
               // - 包含完整的函数调用信息
               
               calldatacopy(0, 0, calldatasize())
           }
           
        4. delegatecall 将这些数据传递给实现合约：
           - 实现合约收到完全相同的 calldata
           - 就像用户直接调用实现合约一样
        */
    }
}

/**
 * @dev 实际的调用示例和数据追踪
 */
contract CallTracker {
    event CalldataReceived(bytes data, bytes4 selector, uint256 size);
    
    fallback() external payable {
        // 记录接收到的 calldata
        emit CalldataReceived(msg.data, bytes4(msg.data), msg.data.length);
        
        assembly {
            // 这里展示 calldatacopy 复制的具体内容
            let size := calldatasize()
            
            // 创建临时存储来展示数据
            let tempPtr := mload(0x40)
            mstore(0x40, add(tempPtr, size))
            
            // 这就是 calldatacopy(0, 0, calldatasize()) 复制的内容：
            calldatacopy(tempPtr, 0, size)
            
            // tempPtr 现在包含：
            // - 完整的函数选择器
            // - 完整的参数数据
            // - 原始调用的所有信息
        }
    }
}

/**
 * @dev 数据来源的完整流程
 */
contract DataSourceFlow {
    /*
    calldata 的完整数据流：
    
    1. 数据产生源头：
       ├── 用户钱包 (MetaMask, etc.)
       ├── 前端应用 (web3.js, ethers.js)
       ├── 后端脚本 (Node.js, Python)
       ├── 其他智能合约
       └── 区块链浏览器
    
    2. 数据编码过程：
       ├── ABI 编码：函数名+参数 -> 字节码
       ├── 函数选择器：keccak256(函数签名)前4字节
       ├── 参数编码：按照 ABI 规则编码参数
       └── 组合：选择器 + 编码后的参数
    
    3. 网络传输：
       ├── 调用者发送交易
       ├── 以太坊网络处理
       ├── EVM 接收 calldata
       └── 传递给目标合约
    
    4. 代理合约处理：
       ├── fallback 函数接收 calldata
       ├── calldatacopy 复制数据到内存
       ├── delegatecall 转发给实现合约
       └── 实现合约执行业务逻辑
    */
}
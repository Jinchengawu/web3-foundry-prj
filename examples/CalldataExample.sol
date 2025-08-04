// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CalldataExample {
    
    /**
     * @dev 演示 calldata 的具体内容和来源
     */
    
    // 假设这是一个 ERC721 合约的函数
    function mint(address to, uint256 tokenId) external {
        // 当调用这个函数时，calldata 包含什么？
    }
    
    /**
     * @dev 演示不同函数调用的 calldata 内容
     */
    function demonstrateCalldata() external view returns (
        bytes memory calldataBytes,
        bytes4 selector,
        uint256 calldataLength
    ) {
        calldataBytes = msg.data;  // 获取完整的调用数据
        selector = bytes4(msg.data);  // 获取函数选择器
        calldataLength = msg.data.length;  // 获取数据长度
    }
    
    /**
     * @dev 用汇编展示 calldata 的详细结构
     */
    function analyzeCalldata() external view returns (
        bytes4 functionSelector,
        bytes memory parameters,
        uint256 totalSize
    ) {
        assembly {
            // 获取总的 calldata 大小
            totalSize := calldatasize()
            
            // 获取函数选择器（前4字节）
            functionSelector := shr(224, calldataload(0))
            
            // 计算参数大小
            let paramSize := sub(calldatasize(), 4)
            
            // 分配内存来存储参数
            parameters := mload(0x40)  // 获取空闲内存指针
            mstore(0x40, add(parameters, add(paramSize, 0x20)))  // 更新空闲内存指针
            mstore(parameters, paramSize)  // 存储参数长度
            
            // 复制参数数据（跳过前4字节的函数选择器）
            calldatacopy(add(parameters, 0x20), 4, paramSize)
        }
    }
}

/**
 * @dev 具体演示代理合约中 calldata 的传递过程
 */
contract CalldataProxy {
    address public implementation;
    
    constructor(address _impl) {
        implementation = _impl;
    }
    
    /**
     * @dev 展示 calldata 在代理合约中的完整传递过程
     */
    fallback() external payable {
        assembly {
            // 1. 打印当前的 calldata 信息（仅演示，实际不能在汇编中打印）
            // 这里的 calldata 包含：
            // - 调用者想要调用的目标函数的选择器
            // - 调用者传递给目标函数的所有参数
            
            let calldataSize := calldatasize()
            
            // 2. 完整复制所有 calldata
            calldatacopy(0, 0, calldataSize)
            
            // 此时内存位置 0 开始包含：
            // 0x00-0x03: 函数选择器 (4 bytes)
            // 0x04-...:   函数参数
            
            // 3. 委托调用，传递完整的 calldata
            let impl := sload(implementation.slot)
            let result := delegatecall(gas(), impl, 0, calldataSize, 0, 0)
            
            // 4. 处理返回数据
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/**
 * @dev 实现合约示例
 */
contract ImplementationContract {
    uint256 public value;
    string public name;
    
    function setValue(uint256 _value) external {
        value = _value;
    }
    
    function setName(string memory _name) external {
        name = _name;
    }
    
    function getValue() external view returns (uint256) {
        return value;
    }
}

/**
 * @dev 演示具体的调用场景
 */
contract CalldataDemo {
    CalldataProxy public proxy;
    ImplementationContract public impl;
    
    constructor() {
        impl = new ImplementationContract();
        proxy = new CalldataProxy(address(impl));
    }
    
    /**
     * @dev 演示不同函数调用的 calldata
     */
    function demonstrateSpecificCalldata() external {
        
        // 场景1: 调用 setValue(123)
        // 生成的 calldata:
        // 0x55241077  <- setValue(uint256) 的函数选择器
        // 0x000000000000000000000000000000000000000000000000000000000000007b  <- 参数 123
        
        // 场景2: 调用 setName("Hello")
        // 生成的 calldata:
        // 0xc47f0027  <- setName(string) 的函数选择器
        // 0x0000000000000000000000000000000000000000000000000000000000000020  <- 字符串偏移
        // 0x0000000000000000000000000000000000000000000000000000000000000005  <- 字符串长度
        // 0x48656c6c6f000000000000000000000000000000000000000000000000000000  <- "Hello"
        
        // 场景3: 调用 getValue()
        // 生成的 calldata:
        // 0x20965255  <- getValue() 的函数选择器（无参数）
    }
}
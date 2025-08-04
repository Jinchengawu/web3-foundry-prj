// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MemoryLayoutExample {
    
    /**
     * @dev 演示不同内存布局的影响
     */
    function demonstrateMemoryLayout() external pure returns (bytes memory) {
        bytes memory result;
        
        assembly {
            // 假设我们有一些调用数据
            let dataSize := 0x40  // 64 bytes 的数据
            
            // 方案1: 从位置 0 开始（推荐）
            // calldatacopy(0, 0, dataSize)
            // - 优点: 简单、直接
            // - 缺点: 可能覆盖临时存储区域
            
            // 方案2: 从位置 0x60 开始（更安全但复杂）
            // calldatacopy(0x60, 0, dataSize)
            // - 优点: 避免覆盖重要内存区域
            // - 缺点: 需要额外的偏移计算
            
            // 在代理合约中，我们选择方案1的原因：
            // 1. 代理合约不需要保留任何状态
            // 2. 立即转发，不做其他操作
            // 3. 最大化执行效率
        }
        
        return result;
    }
    
    /**
     * @dev 演示调用数据起始位置的重要性
     */
    function demonstrateCalldataLayout() external view {
        assembly {
            // 完整的调用数据结构：
            // 0x00-0x03: 函数选择器 (4 bytes)
            // 0x04-....: 参数数据
            
            let selector := shr(224, calldataload(0))  // 获取函数选择器
            
            // 正确的转发必须包含选择器
            // calldatacopy(0, 0, calldatasize())  ✅ 包含选择器
            // calldatacopy(0, 4, calldatasize()-4) ❌ 丢失选择器
        }
    }
}

/**
 * @dev 演示代理合约的最佳实践
 */
contract ProxyBestPractice {
    address private implementation;
    
    function delegateCall() external payable {
        assembly {
            // 最佳实践：从 0 开始复制所有数据
            calldatacopy(0, 0, calldatasize())
            
            // 原因分析：
            // 1. 内存位置 0: 最简单的起始位置
            //    - 不需要计算偏移
            //    - 减少 gas 消耗
            //    - 代码更简洁
            
            // 2. 调用数据位置 0: 保证数据完整性
            //    - 包含函数选择器
            //    - 包含所有参数
            //    - 维持调用的完整性
            
            let impl := sload(implementation.slot)
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/**
 * @dev 反面教材：错误的内存使用
 */
contract BadProxyExample {
    address private implementation;
    
    function badDelegateCall() external payable {
        assembly {
            // ❌ 错误示例1：跳过函数选择器
            // calldatacopy(0, 4, calldatasize() - 4)
            // 结果：目标合约无法识别函数
            
            // ❌ 错误示例2：使用错误的内存位置
            // calldatacopy(0x1000, 0, calldatasize())
            // let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // 结果：传递错误的数据给目标合约
            
            // ❌ 错误示例3：部分数据复制
            // calldatacopy(0, 0, 32)  // 只复制32字节
            // 结果：参数数据不完整
        }
    }
}
/**
Proxy合约 要作为基础的 透明代理合约的模版，被其他业务代理合约作为基类 所实现；

实现透明代理模式的核心功能：
1. 存储实现合约地址
2. 通过 delegatecall 转发函数调用
3. 提供升级实现合约的功能
4. 防止函数选择器冲突
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Proxy is Ownable {
    // 实现合约地址
    address private _implementation;
    
    // 自定义错误
    error ZeroAddress();
    error FailedDelegateCall();
    
    // 事件
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    
    /**
     * @dev 构造函数，初始化代理合约
     * @param _owner 代理合约的所有者
     * @param _initialImplementation 初始实现合约地址
     */
    constructor(address _owner, address _initialImplementation) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_initialImplementation == address(0)) revert ZeroAddress();
        _implementation = _initialImplementation;
        emit ImplementationUpgraded(address(0), _initialImplementation);
    }

    /**
     * @dev 内部代理函数，将调用委托给实现合约
     */
    function _delegate() internal {
        address impl = _implementation;
        assembly {
            // 复制调用数据到内存
            calldatacopy(0, 0, calldatasize())
            
            // 委托调用实现合约
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            // 复制返回数据到内存
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                // 委托调用失败，回滚
                revert(0, returndatasize())
            }
            default {
                // 委托调用成功，返回数据
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev 升级实现合约地址（仅所有者可调用）
     * @param _newImplementation 新的实现合约地址
     */
    function upgradeTo(address _newImplementation) public onlyOwner {
        if (_newImplementation == address(0)) revert ZeroAddress();
        
        address oldImplementation = _implementation;
        _implementation = _newImplementation;
        
        emit ImplementationUpgraded(oldImplementation, _newImplementation);
    }
    
    /**
     * @dev 获取当前实现合约地址
     */
    function implementation() public view returns (address) {
        return _implementation;
    }

    /**
     * @dev fallback 函数，将所有调用委托给实现合约
     */
    fallback() external payable {
        _delegate();
    }
    
    /**
     * @dev receive 函数，处理纯 ETH 转账
     */
    receive() external payable {
        _delegate();
    }
}
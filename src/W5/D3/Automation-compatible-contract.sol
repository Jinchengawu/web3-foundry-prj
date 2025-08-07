// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入本地的自动化兼容接口和TokenBankV4合约
import {AutomationCompatibleInterface} from "./IAutomationCompatible.sol";
import "./TokenBankV4.sol";

/**
 * @title BankAutomation
 * @dev 监控TokenBankV4合约，当存款超过阈值时自动触发转移
 * @notice 实现了Chainlink Automation来自动化银行合约的资金管理
 */
contract BankAutomation is AutomationCompatibleInterface {
    // TokenBankV4 合约实例
    TokenBankV4 public immutable bankContract;
    
    // 检查间隔（秒）- 防止过于频繁检查
    uint256 public immutable checkInterval;
    
    // 上次检查时间戳
    uint256 public lastCheckTimestamp;
    
    // 上次执行转移的时间戳
    uint256 public lastTransferTimestamp;
    
    // 最小转移间隔（防止连续转移）
    uint256 public immutable minTransferInterval;
    
    // 合约所有者
    address public immutable owner;
    
    // 事件
    event AutoTransferTriggered(uint256 amount, uint256 timestamp);
    event CheckPerformed(bool upkeepNeeded, uint256 timestamp);
    
    // 错误
    error OnlyOwner();
    error TransferFailed();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    /**
     * @dev 构造函数
     * @param _bankContract TokenBankV4合约地址
     * @param _checkInterval 检查间隔（秒）
     * @param _minTransferInterval 最小转移间隔（秒）
     */
    constructor(
        address _bankContract,
        uint256 _checkInterval,
        uint256 _minTransferInterval
    ) {
        bankContract = TokenBankV4(_bankContract);
        checkInterval = _checkInterval;
        minTransferInterval = _minTransferInterval;
        lastCheckTimestamp = block.timestamp;
        lastTransferTimestamp = block.timestamp;
        owner = msg.sender;
    }
    
    /**
     * @dev Chainlink Automation调用此函数检查是否需要执行upkeep
     * @return upkeepNeeded 是否需要执行upkeep
     * @return performData 执行数据（本例中未使用）
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // 检查是否到了检查时间
        bool timeToCheck = (block.timestamp - lastCheckTimestamp) >= checkInterval;
        
        // 检查是否超过最小转移间隔
        bool transferIntervalPassed = (block.timestamp - lastTransferTimestamp) >= minTransferInterval;
        
        if (timeToCheck && transferIntervalPassed) {
            // 检查银行合约是否需要转移
            (bool needsTransfer, ) = bankContract.checkAutoTransfer();
            upkeepNeeded = needsTransfer;
        } else {
            upkeepNeeded = false;
        }
        
        // performData 在本例中不需要，返回空bytes
        return (upkeepNeeded, "");
    }
    
    /**
     * @dev Chainlink Automation调用此函数执行upkeep
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        // 重新检查条件以确保安全
        bool timeToCheck = (block.timestamp - lastCheckTimestamp) >= checkInterval;
        bool transferIntervalPassed = (block.timestamp - lastTransferTimestamp) >= minTransferInterval;
        
        if (timeToCheck && transferIntervalPassed) {
            (bool needsTransfer, uint256 transferAmount) = bankContract.checkAutoTransfer();
            
            if (needsTransfer) {
                // 执行自动转移
                try bankContract.executeAutoTransfer() {
                    // 更新时间戳
                    lastTransferTimestamp = block.timestamp;
                    
                    emit AutoTransferTriggered(transferAmount, block.timestamp);
                } catch {
                    revert TransferFailed();
                }
            }
        }
        
        // 更新检查时间戳
        lastCheckTimestamp = block.timestamp;
        
        emit CheckPerformed(true, block.timestamp);
    }
    
    /**
     * @dev 获取银行合约的当前状态
     * @return totalDeposit 总存款
     * @return threshold 自动转移阈值
     * @return enabled 是否启用自动转移
     * @return needsTransfer 是否需要转移
     * @return transferAmount 转移金额
     */
    function getBankStatus() 
        external 
        view 
        returns (
            uint256 totalDeposit,
            uint256 threshold,
            bool enabled,
            bool needsTransfer,
            uint256 transferAmount
        ) 
    {
        totalDeposit = bankContract.totalDeposit();
        threshold = bankContract.autoTransferThreshold();
        enabled = bankContract.autoTransferEnabled();
        (needsTransfer, transferAmount) = bankContract.checkAutoTransfer();
    }
    
    /**
     * @dev 手动触发检查（仅用于测试）
     */
    function manualCheck() external view returns (bool needsTransfer, uint256 transferAmount) {
        return bankContract.checkAutoTransfer();
    }
    
    /**
     * @dev 获取自动化合约的状态信息
     */
    function getAutomationStatus() 
        external 
        view 
        returns (
            uint256 lastCheck,
            uint256 lastTransfer,
            uint256 nextCheckTime,
            uint256 nextTransferTime
        ) 
    {
        lastCheck = lastCheckTimestamp;
        lastTransfer = lastTransferTimestamp;
        nextCheckTime = lastCheckTimestamp + checkInterval;
        nextTransferTime = lastTransferTimestamp + minTransferInterval;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
先实现一个 Bank 合约， 用户可以通过 deposit() 存款， 然后使用 ChainLink Automation 、
实现一个自动化任务， 自动化任务实现：
当 Bank 合约的存款超过 x (可自定义数量)时， 转移一半的存款到指定的地址（如 Owner）。
*/

import {TokenBankV3} from "../../W3/D5/TokenBankV3.sol";
import {TokenV3} from "../../W3/D5/TokenV3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenBankV4 is TokenBankV3 {
    // 自动转移的阈值
    uint256 public autoTransferThreshold;
    
    // 自动化合约地址，只有它可以触发自动转移
    address public automationContract;
    
    // 是否启用自动转移功能
    bool public autoTransferEnabled;
    
    // 事件
    event AutoTransferThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event AutoTransferExecuted(uint256 amount, address recipient);
    event AutomationContractUpdated(address oldContract, address newContract);
    event AutoTransferToggled(bool enabled);
    
    // 错误
    error OnlyAutomationContract();
    error AutoTransferDisabled();
    error InsufficientBalance();
    error TransferFailed();
    error OnlyOwner();
    
    modifier onlyAutomation() {
        if (msg.sender != automationContract) revert OnlyAutomationContract();
        _;
    }
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    constructor(TokenV3 _token, uint256 _threshold) TokenBankV3(_token) {
        autoTransferThreshold = _threshold;
        autoTransferEnabled = true;
        
        emit AutoTransferThresholdUpdated(0, _threshold);
    }
    
    /**
     * @dev 设置自动化合约地址（只有owner可以调用）
     */
    function setAutomationContract(address _automationContract) external onlyOwner {
        address oldContract = automationContract;
        automationContract = _automationContract;
        emit AutomationContractUpdated(oldContract, _automationContract);
    }
    
    /**
     * @dev 更新自动转移阈值（只有owner可以调用）
     */
    function updateAutoTransferThreshold(uint256 _newThreshold) external onlyOwner {
        uint256 oldThreshold = autoTransferThreshold;
        autoTransferThreshold = _newThreshold;
        emit AutoTransferThresholdUpdated(oldThreshold, _newThreshold);
    }
    
    /**
     * @dev 切换自动转移功能开关（只有owner可以调用）
     */
    function toggleAutoTransfer(bool _enabled) external onlyOwner {
        autoTransferEnabled = _enabled;
        emit AutoTransferToggled(_enabled);
    }
    
    /**
     * @dev 检查是否需要执行自动转移
     * @return needsTransfer 是否需要转移
     * @return transferAmount 转移金额
     */
    function checkAutoTransfer() external view returns (bool needsTransfer, uint256 transferAmount) {
        if (!autoTransferEnabled) {
            return (false, 0);
        }
        
        if (totalDeposit > autoTransferThreshold) {
            transferAmount = totalDeposit / 2; // 转移一半
            needsTransfer = transferAmount > 0;
        }
        
        return (needsTransfer, transferAmount);
    }
    
    /**
     * @dev 执行自动转移（只有自动化合约可以调用）
     */
    function executeAutoTransfer() external onlyAutomation {
        if (!autoTransferEnabled) revert AutoTransferDisabled();
        
        if (totalDeposit <= autoTransferThreshold) revert InsufficientBalance();
        
        uint256 transferAmount = totalDeposit / 2;
        if (transferAmount == 0) revert InsufficientBalance();
        
        // 更新总存款
        totalDeposit -= transferAmount;
        
        // 转移代币到owner
        bool success = token.transfer(owner, transferAmount);
        if (!success) revert TransferFailed();
        
        emit AutoTransferExecuted(transferAmount, owner);
    }
    
    /**
     * @dev 手动执行转移（紧急情况下owner可以调用）
     */
    function manualTransfer() external onlyOwner {
        if (totalDeposit <= autoTransferThreshold) revert InsufficientBalance();
        
        uint256 transferAmount = totalDeposit / 2;
        if (transferAmount == 0) revert InsufficientBalance();
        
        // 更新总存款
        totalDeposit -= transferAmount;
        
        // 转移代币到owner
        bool success = token.transfer(owner, transferAmount);
        if (!success) revert TransferFailed();
        
        emit AutoTransferExecuted(transferAmount, owner);
    }
    
    /**
     * @dev 获取当前合约的代币余额
     */
    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

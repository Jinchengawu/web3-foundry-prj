// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
部署自己的 Delegate 合约（需支持批量执行）到 Sepolia。
修改之前的TokenBank 前端页面，让用户能够通过 EOA 账户授权给 Delegate 合约，
并在一个交易中完成授权和存款操作。

功能特性：
1. 支持批量执行（multicall）
2. 支持代理调用（delegatecall）
3. 支持与 TokenBank 的授权和存款操作
4. 支持紧急停止功能
 */
contract Delegate is Ownable, ReentrancyGuard {
    
    // 状态变量
    bool public paused;
    mapping(address => bool) public authorizedCallers;
    
    // 批量调用结构体
    struct Call {
        address target;
        bytes callData;
    }
    
    struct CallWithValue {
        address target;
        uint256 value;
        bytes callData;
    }
    
    // 事件
    event BatchExecuted(address indexed caller, uint256 callCount);
    event DelegateCallExecuted(address indexed caller, address indexed target, bool success);
    event TokenApproved(address indexed token, address indexed spender, uint256 amount);
    event TokenDeposited(address indexed bank, address indexed token, uint256 amount);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);
    event PausedStateChanged(bool paused);
    
    // 错误
    error ContractPaused();
    error UnauthorizedCaller();
    error CallFailed(uint256 index, bytes reason);
    error ArrayLengthMismatch();
    error ZeroAddress();
    error InsufficientBalance();
    
    // 修饰符
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender] && msg.sender != owner()) {
            revert UnauthorizedCaller();
        }
        _;
    }

    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
    }

    // === 权限管理 ===
    
    /**
     * @dev 添加授权调用者
     */
    function addAuthorizedCaller(address caller) external onlyOwner {
        if (caller == address(0)) revert ZeroAddress();
        authorizedCallers[caller] = true;
        emit AuthorizedCallerAdded(caller);
    }
    
    /**
     * @dev 移除授权调用者
     */
    function removeAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit AuthorizedCallerRemoved(caller);
    }
    
    /**
     * @dev 设置暂停状态
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // === 批量执行功能 ===
    
    /**
     * @dev 批量执行调用（不带 ETH 值）
     * @param calls 调用数组
     * @return results 执行结果数组
     */
    function multicall(Call[] calldata calls) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (bytes[] memory results) 
    {
        results = new bytes[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call(calls[i].callData);
            if (!success) {
                revert CallFailed(i, result);
            }
            results[i] = result;
        }
        
        emit BatchExecuted(msg.sender, calls.length);
        return results;
    }
    
    /**
     * @dev 批量执行调用（带 ETH 值）
     * @param calls 调用数组
     * @return results 执行结果数组
     */
    function multicallWithValue(CallWithValue[] calldata calls) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (bytes[] memory results) 
    {
        results = new bytes[](calls.length);
        uint256 totalValue = 0;
        
        // 计算总 ETH 值
        for (uint256 i = 0; i < calls.length; i++) {
            totalValue += calls[i].value;
        }
        
        if (totalValue > msg.value) revert InsufficientBalance();
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call{value: calls[i].value}(calls[i].callData);
            if (!success) {
                revert CallFailed(i, result);
            }
            results[i] = result;
        }
        
        emit BatchExecuted(msg.sender, calls.length);
        return results;
    }
    
    /**
     * @dev 批量 delegatecall（仅授权用户）
     * @param calls 调用数组
     * @return results 执行结果数组
     */
    function multicallDelegate(Call[] calldata calls) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyAuthorized 
        returns (bytes[] memory results) 
    {
        results = new bytes[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.delegatecall(calls[i].callData);
            if (!success) {
                revert CallFailed(i, result);
            }
            results[i] = result;
            emit DelegateCallExecuted(msg.sender, calls[i].target, success);
        }
        
        emit BatchExecuted(msg.sender, calls.length);
        return results;
    }

    // === TokenBank 交互功能 ===
    
    /**
     * @dev 批准代币并存入 TokenBank
     * @param token 代币地址
     * @param tokenBank TokenBank 合约地址
     * @param amount 存款金额
     */
    function approveAndDeposit(
        address token,
        address tokenBank,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        if (token == address(0) || tokenBank == address(0)) revert ZeroAddress();
        
        // 转移代币到此合约
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // 批准 TokenBank 使用代币
        IERC20(token).approve(tokenBank, amount);
        emit TokenApproved(token, tokenBank, amount);
        
        // 调用 TokenBank 的 deposit 方法
        (bool success, ) = tokenBank.call(
            abi.encodeWithSignature("deposit(uint256)", amount)
        );
        require(success, "Delegate: TokenBank deposit failed");
        
        emit TokenDeposited(tokenBank, token, amount);
    }
    
    /**
     * @dev 批量批准代币并存入 TokenBank
     * @param tokens 代币地址数组
     * @param tokenBanks TokenBank 合约地址数组
     * @param amounts 存款金额数组
     */
    function batchApproveAndDeposit(
        address[] calldata tokens,
        address[] calldata tokenBanks,
        uint256[] calldata amounts
    ) external nonReentrant whenNotPaused {
        if (tokens.length != tokenBanks.length || tokens.length != amounts.length) {
            revert ArrayLengthMismatch();
        }
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0) || tokenBanks[i] == address(0)) revert ZeroAddress();
            
            // 转移代币到此合约
            IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
            
            // 批准 TokenBank 使用代币
            IERC20(tokens[i]).approve(tokenBanks[i], amounts[i]);
            emit TokenApproved(tokens[i], tokenBanks[i], amounts[i]);
            
            // 调用 TokenBank 的 deposit 方法
            (bool success, ) = tokenBanks[i].call(
                abi.encodeWithSignature("deposit(uint256)", amounts[i])
            );
            require(success, "Delegate: TokenBank deposit failed");
            
            emit TokenDeposited(tokenBanks[i], tokens[i], amounts[i]);
        }
        
        emit BatchExecuted(msg.sender, tokens.length);
    }

    // === 代理调用功能 ===
    
    /**
     * @dev 执行 delegatecall（仅授权用户）
     * @param target 目标合约地址
     * @param data 调用数据
     * @return success 是否成功
     * @return returnData 返回数据
     */
    function delegateCall(address target, bytes calldata data) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyAuthorized 
        returns (bool success, bytes memory returnData) 
    {
        (success, returnData) = target.delegatecall(data);
        emit DelegateCallExecuted(msg.sender, target, success);
    }

    // === 紧急功能 ===
    
    /**
     * @dev 紧急提取代币（仅所有者）
     * @param token 代币地址
     * @param to 接收地址
     * @param amount 提取金额
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).transfer(to, amount);
    }
    
    /**
     * @dev 紧急提取 ETH（仅所有者）
     * @param to 接收地址
     * @param amount 提取金额
     */
    function emergencyWithdrawETH(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        to.transfer(amount);
    }

    // === 工具函数 ===
    
    /**
     * @dev 检查合约是否授权给指定地址
     * @param token 代币地址
     * @param spender 花费者地址
     * @return 授权金额
     */
    function getAllowance(address token, address spender) external view returns (uint256) {
        return IERC20(token).allowance(address(this), spender);
    }
    
    /**
     * @dev 获取合约代币余额
     * @param token 代币地址
     * @return 余额
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @dev 获取合约 ETH 余额
     * @return 余额
     */
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // === 接收 ETH ===
    
    receive() external payable {}
    
    fallback() external payable {}
}
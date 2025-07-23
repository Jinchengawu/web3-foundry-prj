/**
在 Safe Wallet 支持的测试网上创建一个 2/3 多签钱包。
然后：

往多签中存入自己创建的任意 ERC20 Token。
从多签中转出一定数量的 ERC20 Token。
把 Bank 合约的管理员设置为多签。
请贴 Safe 的钱包链接。
5. 从多签中发起， 对 Bank 的 withdraw 的调用
*/

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenBankV2} from '../../W2/D3/TokenBank_Plus.sol';
import {ERC20V2} from '../../W2/D3/ERC20_Plus.sol';

contract SafeBank is TokenBankV2 {
    // 多签账户结构
    struct SafeBankAccount {
        uint256 id;
        address[] owners;           // 多签所有者列表
        uint256 requiredSignatures; // 需要的签名数量
        mapping(address => bool) isOwner;
        mapping(uint256 => OrderInfo) orders;
        uint256 orderCount;
        mapping(address => uint256) tokenBalances; // 每个token的余额
    }

    // 订单信息结构
    struct OrderInfo {
        uint256 id;
        address owner;
        uint256 amount;    
        address token;
        address to;
        uint256 deadline;
        bool isCancelled;
        bool isApproved;
        bool isRejected;
        bool isExecuted;
        mapping(address => bool) approvals; // 记录每个所有者的审批状态
        uint256 approvalCount;
    }

    // 全局变量
    mapping(uint256 => SafeBankAccount) public safeBankAccounts;
    uint256 public nextAccountId = 1;
    
    // 事件
    event SafeBankAccountCreated(uint256 indexed accountId, address[] owners, uint256 requiredSignatures);
    event OrderCreated(uint256 indexed accountId, uint256 indexed orderId, address owner, uint256 amount, address token, address to);
    event OrderApproved(uint256 indexed accountId, uint256 indexed orderId, address approver);
    event OrderRejected(uint256 indexed accountId, uint256 indexed orderId, address rejector);
    event OrderExecuted(uint256 indexed accountId, uint256 indexed orderId);
    event OrderCancelled(uint256 indexed accountId, uint256 indexed orderId);
    event TokenDeposited(uint256 indexed accountId, address token, uint256 amount);
    event TokenWithdrawn(uint256 indexed accountId, address token, uint256 amount, address to);

    constructor(ERC20V2 _token) TokenBankV2(_token) {}

    /**
     * 1. 创建多签账户
     * @param owners 多签所有者列表
     * @param requiredSignatures 需要的签名数量
     */
    function createSafeBankAccount(address[] memory owners, uint256 requiredSignatures) public returns (uint256) {
        require(owners.length >= 2, "At least 2 owners required");
        require(requiredSignatures >= 2, "At least 2 signatures required");
        require(requiredSignatures <= owners.length, "Required signatures cannot exceed owners count");
        
        uint256 accountId = nextAccountId++;
        SafeBankAccount storage account = safeBankAccounts[accountId];
        account.id = accountId;
        account.requiredSignatures = requiredSignatures;
        
        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), "Invalid owner address");
            require(!account.isOwner[owners[i]], "Duplicate owner");
            account.owners.push(owners[i]);
            account.isOwner[owners[i]] = true;
        }
        
        emit SafeBankAccountCreated(accountId, owners, requiredSignatures);
        return accountId;
    }

    /**
     * 2. 往多签中存入ERC20 Token
     * @param accountId 多签账户ID
     * @param token ERC20代币地址
     * @param amount 存入数量
     */
    function depositToSafeBank(uint256 accountId, address token, uint256 amount) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        require(account.id != 0, "Account does not exist");
        require(amount > 0, "Amount must be greater than 0");
        
        // 转移代币到合约
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        account.tokenBalances[token] += amount;
        
        emit TokenDeposited(accountId, token, amount);
    }

    /**
     * 3. 创建从多签中转出ERC20 Token的订单
     * @param accountId 多签账户ID
     * @param token ERC20代币地址
     * @param amount 转出数量
     * @param to 接收地址
     * @param deadline 截止时间
     */
    function createWithdrawOrder(uint256 accountId, address token, uint256 amount, address to, uint256 deadline) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        require(account.id != 0, "Account does not exist");
        require(account.isOwner[msg.sender], "Only owner can create orders");
        require(account.tokenBalances[token] >= amount, "Insufficient token balance");
        require(to != address(0), "Invalid recipient address");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        uint256 orderId = account.orderCount++;
        OrderInfo storage order = account.orders[orderId];
        order.id = orderId;
        order.owner = msg.sender;
        order.amount = amount;
        order.token = token;
        order.to = to;
        order.deadline = deadline;
        
        emit OrderCreated(accountId, orderId, msg.sender, amount, token, to);
    }

    /**
     * 审批订单
     * @param accountId 多签账户ID
     * @param orderId 订单ID
     */
    function approveOrder(uint256 accountId, uint256 orderId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        
        require(account.id != 0, "Account does not exist");
        require(order.id != 0, "Order does not exist");
        require(account.isOwner[msg.sender], "Only owner can approve");
        require(!order.isCancelled && !order.isExecuted, "Order is not active");
        require(block.timestamp <= order.deadline, "Order expired");
        require(!order.approvals[msg.sender], "Already approved");
        
        order.approvals[msg.sender] = true;
        order.approvalCount++;
        
        emit OrderApproved(accountId, orderId, msg.sender);
        
        // 如果达到所需签名数量，自动执行
        if (order.approvalCount >= account.requiredSignatures) {
            executeOrder(accountId, orderId);
        }
    }

    /**
     * 拒绝订单
     * @param accountId 多签账户ID
     * @param orderId 订单ID
     */
    function rejectOrder(uint256 accountId, uint256 orderId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        
        require(account.id != 0, "Account does not exist");
        require(order.id != 0, "Order does not exist");
        require(account.isOwner[msg.sender], "Only owner can reject");
        require(!order.isCancelled && !order.isExecuted, "Order is not active");
        
        order.isRejected = true;
        
        emit OrderRejected(accountId, orderId, msg.sender);
    }

    /**
     * 执行订单
     * @param accountId 多签账户ID
     * @param orderId 订单ID
     */
    function executeOrder(uint256 accountId, uint256 orderId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        
        require(account.id != 0, "Account does not exist");
        require(order.id != 0, "Order does not exist");
        require(!order.isCancelled && !order.isExecuted, "Order is not active");
        require(block.timestamp <= order.deadline, "Order expired");
        require(order.approvalCount >= account.requiredSignatures, "Insufficient approvals");
        
        // 执行转账
        require(account.tokenBalances[order.token] >= order.amount, "Insufficient balance");
        account.tokenBalances[order.token] -= order.amount;
        IERC20(order.token).transfer(order.to, order.amount);
        
        order.isExecuted = true;
        
        emit OrderExecuted(accountId, orderId);
        emit TokenWithdrawn(accountId, order.token, order.amount, order.to);
    }

    /**
     * 取消订单
     * @param accountId 多签账户ID
     * @param orderId 订单ID
     */
    function cancelOrder(uint256 accountId, uint256 orderId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        
        require(account.id != 0, "Account does not exist");
        require(order.id != 0, "Order does not exist");
        require(order.owner == msg.sender, "Only order owner can cancel");
        require(!order.isCancelled && !order.isExecuted, "Order is not active");
        
        order.isCancelled = true;
        
        emit OrderCancelled(accountId, orderId);
    }

    /**
     * 4. 设置Bank合约的管理员为多签账户
     */
    function setBankOwnerToSafeBank(uint256 accountId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        require(account.id != 0, "Account does not exist");
        require(account.isOwner[msg.sender], "Only owner can set bank owner");
        
        // 将Bank合约的所有者设置为SafeBank合约
        setOwner(address(this));
    }

    /**
     * 5. 从多签中发起对Bank的withdraw调用
     * 创建从Bank合约提取代币的订单
     */
    function createBankWithdrawOrder(uint256 accountId, uint256 amount, uint256 deadline) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        require(account.id != 0, "Account does not exist");
        require(account.isOwner[msg.sender], "Only owner can create orders");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        uint256 orderId = account.orderCount++;
        OrderInfo storage order = account.orders[orderId];
        order.id = orderId;
        order.owner = msg.sender;
        order.amount = amount;
        order.token = address(token); // 使用Bank合约的代币
        order.to = address(this); // 提取到SafeBank合约
        order.deadline = deadline;
        
        emit OrderCreated(accountId, orderId, msg.sender, amount, address(token), address(this));
    }

    /**
     * 执行Bank提取订单
     */
    function executeBankWithdrawOrder(uint256 accountId, uint256 orderId) public {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        
        require(account.id != 0, "Account does not exist");
        require(order.id != 0, "Order does not exist");
        require(!order.isCancelled && !order.isExecuted, "Order is not active");
        require(block.timestamp <= order.deadline, "Order expired");
        require(order.approvalCount >= account.requiredSignatures, "Insufficient approvals");
        require(order.token == address(token), "Not a bank withdraw order");
        
        // 执行Bank合约的withdraw
        super.withdraw(order.amount);
        
        // 将提取的代币添加到SafeBank账户余额
        account.tokenBalances[address(token)] += order.amount;
        
        order.isExecuted = true;
        
        emit OrderExecuted(accountId, orderId);
        emit TokenDeposited(accountId, address(token), order.amount);
    }

    // 查询函数
    function getSafeBankAccount(uint256 accountId) public view returns (
        uint256 id,
        address[] memory owners,
        uint256 requiredSignatures,
        uint256 orderCount
    ) {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        return (account.id, account.owners, account.requiredSignatures, account.orderCount);
    }

    function getOrder(uint256 accountId, uint256 orderId) public view returns (
        uint256 id,
        address owner,
        uint256 amount,
        address token,
        address to,
        uint256 deadline,
        bool isCancelled,
        bool isApproved,
        bool isRejected,
        bool isExecuted,
        uint256 approvalCount
    ) {
        SafeBankAccount storage account = safeBankAccounts[accountId];
        OrderInfo storage order = account.orders[orderId];
        return (
            order.id,
            order.owner,
            order.amount,
            order.token,
            order.to,
            order.deadline,
            order.isCancelled,
            order.isApproved,
            order.isRejected,
            order.isExecuted,
            order.approvalCount
        );
    }

    function getTokenBalance(uint256 accountId, address token) public view returns (uint256) {
        return safeBankAccounts[accountId].tokenBalances[token];
    }

    function isOwner(uint256 accountId, address owner) public view returns (bool) {
        return safeBankAccounts[accountId].isOwner[owner];
    }

    function hasApproved(uint256 accountId, uint256 orderId, address owner) public view returns (bool) {
        return safeBankAccounts[accountId].orders[orderId].approvals[owner];
    }

    // 重写TokenBankV2的deposit和withdraw函数，使其与SafeBank集成
    function deposit(uint256 amount) public override {
        super.deposit(amount);
    }

    function withdraw(uint256 amount) public override {
        super.withdraw(amount);
    }
}

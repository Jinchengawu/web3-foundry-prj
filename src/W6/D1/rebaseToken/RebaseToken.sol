// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/**
 * @title RebaseToken
 * @dev 通缩型ERC20 Token，通过rebase机制实现每年1%的通缩
 * @author dreamworks.cnn@gmail.com
 */
contract RebaseToken is ERC20, Ownable, ReentrancyGuard {

    // 核心变量
    uint256 private _totalSupply;
    uint256 private _rebaseIndex; // 精度: 1e18
    uint256 private _lastRebaseTime;
    uint256 private _annualDeflation; // 年通缩率 (1% = 100)
    uint256 private constant MIN_REBASE_INTERVAL = 1 days; // 最小rebase间隔
    uint256 private constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿枚
    uint256 private constant ANNUAL_DEFLATION_RATE = 100; // 1% = 100

    // 用户原始余额映射
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // 事件定义
    event Rebase(
        uint256 indexed timestamp,
        uint256 oldIndex,
        uint256 newIndex,
        uint256 oldSupply,
        uint256 newSupply
    );

    /**
     * @dev 构造函数
     * @param name Token名称
     * @param symbol Token符号
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _totalSupply = INITIAL_SUPPLY;
        _rebaseIndex = 1e18; // 初始rebase指数
        _lastRebaseTime = block.timestamp;
        _annualDeflation = ANNUAL_DEFLATION_RATE;
        
        // 将初始供应量分配给部署者
        _balances[msg.sender] = INITIAL_SUPPLY;
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev 获取用户实际余额
     * @param account 用户地址
     * @return 实际余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account]*_rebaseIndex /1e18;
    }

    /**
     * @dev 获取当前总供应量
     * @return 当前总供应量
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply * _rebaseIndex / 1e18;
    }

    /**
     * @dev 获取当前rebase指数
     * @return rebase指数
     */
    function getRebaseIndex() public view returns (uint256) {
        return _rebaseIndex;
    }

    /**
     * @dev 获取上次rebase时间
     * @return 上次rebase时间戳
     */
    function getLastRebaseTime() public view returns (uint256) {
        return _lastRebaseTime;
    }

    /**
     * @dev 获取年通缩率
     * @return 年通缩率
     */
    function getAnnualDeflation() public view returns (uint256) {
        return _annualDeflation;
    }

    /**
     * @dev 执行rebase操作
     * 只有合约所有者可以调用
     */
    function rebase() external onlyOwner nonReentrant {
        require(
            block.timestamp >= _lastRebaseTime + MIN_REBASE_INTERVAL,
            "RebaseToken: Rebase interval not met"
        );

        uint256 oldIndex = _rebaseIndex;
        uint256 oldSupply = totalSupply();

        // 计算新的rebase指数
        // newIndex = oldIndex * (1 - annualDeflation / 10000)
        uint256 deflationFactor = 10000 - _annualDeflation;
        _rebaseIndex = _rebaseIndex * deflationFactor / 10000;

        _lastRebaseTime = block.timestamp;

        uint256 newSupply = totalSupply();

        emit Rebase(block.timestamp, oldIndex, _rebaseIndex, oldSupply, newSupply);
    }

    /**
     * @dev 转账功能
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "RebaseToken: Transfer to zero address");
        require(amount > 0, "RebaseToken: Transfer amount must be positive");

        address owner = _msgSender();
        uint256 ownerBalance = balanceOf(owner);
        require(ownerBalance >= amount, "RebaseToken: Insufficient balance");

        // 计算原始余额的转账数量
        uint256 rawAmount = amount * 1e18 / _rebaseIndex;

        _balances[owner] = _balances[owner] - rawAmount;
        _balances[to] = _balances[to] + rawAmount;

        emit Transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev 授权转账功能
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "RebaseToken: Transfer to zero address");
        require(amount > 0, "RebaseToken: Transfer amount must be positive");

        address spender = _msgSender();
        uint256 currentAllowance = allowance(from, spender);
        require(currentAllowance >= amount, "RebaseToken: Insufficient allowance");

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "RebaseToken: Insufficient balance");

        // 计算原始余额的转账数量
        uint256 rawAmount = amount * 1e18 / _rebaseIndex;

        _balances[from] = _balances[from] - rawAmount;
        _balances[to] = _balances[to] + rawAmount;

        _spendAllowance(from, spender, amount);

        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @dev 授权功能
     * @param spender 被授权地址
     * @param amount 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev 增加授权额度
     * @param spender 被授权地址
     * @param addedValue 增加的授权金额
     * @return 是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev 减少授权额度
     * @param spender 被授权地址
     * @param subtractedValue 减少的授权金额
     * @return 是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "RebaseToken: Decreased allowance below zero");
        _approve(owner, spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
     * @dev 获取授权额度
     * @param owner 所有者地址
     * @param spender 被授权地址
     * @return 授权额度
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev 内部授权函数
     * @param owner 所有者地址
     * @param spender 被授权地址
     * @param amount 授权金额
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount,
        bool emitEvent
    ) internal virtual override {
        require(owner != address(0), "RebaseToken: Approve from zero address");
        require(spender != address(0), "RebaseToken: Approve to zero address");

        _allowances[owner][spender] = amount;
        if (emitEvent) {
            emit Approval(owner, spender, amount);
        }
    }

    /**
     * @dev 消费授权额度
     * @param owner 所有者地址
     * @param spender 被授权地址
     * @param amount 消费金额
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal override {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "RebaseToken: Insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    /**
     * @dev 获取用户原始余额（内部使用）
     * @param account 用户地址
     * @return 原始余额
     */
    function _getRawBalance(address account) internal view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev 设置年通缩率（仅所有者）
     * @param newDeflationRate 新的年通缩率
     */
    function setAnnualDeflation(uint256 newDeflationRate) external onlyOwner {
        require(newDeflationRate <= 1000, "RebaseToken: Deflation rate too high"); // 最大10%
        _annualDeflation = newDeflationRate;
    }

    /**
     * @dev 获取合约信息
     * @return totalSupply_ 原始总供应量
     * @return rebaseIndex_ 当前rebase指数
     * @return lastRebaseTime_ 上次rebase时间
     * @return annualDeflation_ 年通缩率
     * @return actualTotalSupply 当前实际总供应量
     */
    function getContractInfo() external view returns (
        uint256 totalSupply_,
        uint256 rebaseIndex_,
        uint256 lastRebaseTime_,
        uint256 annualDeflation_,
        uint256 actualTotalSupply
    ) {
        return (
            _totalSupply,
            _rebaseIndex,
            _lastRebaseTime,
            _annualDeflation,
            totalSupply()
        );
    }
} 

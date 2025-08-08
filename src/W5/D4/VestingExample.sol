// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Vesting合约 - 展示Solidity中各种时间变量类型
 * @dev 这个合约展示了在Solidity中存储和处理时间的各种方式
 */
contract VestingExample is Ownable {
    
    // ========== 各种时间变量类型示例 ==========
    
    // 1. uint256 - 最常用的时间戳类型（Unix时间戳，秒级精度）
    uint256 public immutable deployTimestamp;      // 合约部署时间戳
    uint256 public immutable cliffTimestamp;       // 悬崖期结束时间戳
    uint256 public immutable vestingEndTimestamp;  // 归属期结束时间戳
    
    // 2. uint64 - 较小的时间类型，适合存储时间戳（节省gas费用）
    // uint64 可以表示到 2106年，对于大多数应用已经足够
    uint64 public immutable cliffDuration;         // 悬崖期持续时间(秒)
    uint64 public immutable vestingDuration;       // 线性释放持续时间(秒)
    
    // 3. uint48 - OpenZeppelin推荐的时间点类型（ERC-6372标准）
    // uint48 可以表示到 8900年，占用空间更小
    uint48 public immutable startTimepoint;        // 开始时间点
    
    // 4. uint32 - 用于较短的时间间隔或持续时间
    uint32 public constant SECONDS_PER_DAY = 24 * 60 * 60;      // 每天秒数
    uint32 public constant SECONDS_PER_MONTH = 30 * 24 * 60 * 60; // 每月秒数（简化为30天）
    uint32 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60; // 每年秒数
    
    // ========== 合约状态变量 ==========
    IERC20 public immutable token;                 // ERC20代币地址
    mapping(address => uint256) public totalAllocation;  // 每个受益人的总分配量
    mapping(address => uint256) public releasedAmount;   // 每个受益人已释放的数量
    
    // ========== 事件 ==========
    event TokensReleased(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event BeneficiaryAdded(address indexed beneficiary, uint256 amount, uint256 timestamp);
    
    constructor(
        address _token,
        address _beneficiary,
        uint256 _totalAmount
    ) Ownable(msg.sender) {
        require(_token != address(0), "Token address cannot be zero");
        require(_beneficiary != address(0), "Beneficiary address cannot be zero");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        
        token = IERC20(_token);
        
        // 记录各种时间类型
        deployTimestamp = block.timestamp;               // uint256 类型
        startTimepoint = uint48(block.timestamp);        // uint48 类型
        
        // 计算时间参数
        cliffDuration = 12 * SECONDS_PER_MONTH;          // uint64: 12个月悬崖期
        vestingDuration = 24 * SECONDS_PER_MONTH;        // uint64: 24个月线性释放
        
        cliffTimestamp = deployTimestamp + cliffDuration;
        vestingEndTimestamp = cliffTimestamp + vestingDuration;
        
        // 设置受益人
        totalAllocation[_beneficiary] = _totalAmount;
        
        emit BeneficiaryAdded(_beneficiary, _totalAmount, block.timestamp);
    }
    
    // ========== 时间检查函数 ==========
    
    /**
     * @dev 检查是否已过悬崖期
     * @return 是否已过悬崖期
     */
    function hasPassedCliff() public view returns (bool) {
        return block.timestamp >= cliffTimestamp;
    }
    
    /**
     * @dev 检查归属期是否已结束
     * @return 是否已结束归属期
     */
    function isVestingComplete() public view returns (bool) {
        return block.timestamp >= vestingEndTimestamp;
    }
    
    // ========== 时间计算函数 ==========
    
    /**
     * @dev 获取当前区块时间戳
     * @return 当前时间戳
     */
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @dev 获取剩余悬崖期时间
     * @return 剩余秒数
     */
    function remainingCliffTime() public view returns (uint256) {
        if (hasPassedCliff()) {
            return 0;
        }
        return cliffTimestamp - block.timestamp;
    }
    
    /**
     * @dev 获取剩余归属期时间
     * @return 剩余秒数
     */
    function remainingVestingTime() public view returns (uint256) {
        if (isVestingComplete()) {
            return 0;
        }
        return vestingEndTimestamp - block.timestamp;
    }
    
    /**
     * @dev 获取归属进度百分比
     * @return 进度百分比 (basis points: 10000 = 100%)
     */
    function vestingProgress() public view returns (uint256) {
        if (!hasPassedCliff()) {
            return 0;
        }
        if (isVestingComplete()) {
            return 10000; // 100%
        }
        
        uint256 timeSinceCliff = block.timestamp - cliffTimestamp;
        return (timeSinceCliff * 10000) / vestingDuration;
    }
    
    // ========== 代币释放逻辑 ==========
    
    /**
     * @dev 计算某个受益人当前可释放的代币数量
     * @param beneficiary 受益人地址
     * @return 可释放的代币数量
     */
    function releasableAmount(address beneficiary) public view returns (uint256) {
        if (!hasPassedCliff()) {
            return 0; // 悬崖期内不能释放
        }
        
        uint256 totalTokens = totalAllocation[beneficiary];
        uint256 alreadyReleased = releasedAmount[beneficiary];
        
        if (isVestingComplete()) {
            return totalTokens - alreadyReleased; // 全部释放
        }
        
        // 线性释放计算
        uint256 timeSinceCliff = block.timestamp - cliffTimestamp;
        uint256 vestedAmount = (totalTokens * timeSinceCliff) / vestingDuration;
        
        return vestedAmount - alreadyReleased;
    }
    
    /**
     * @dev 释放代币给调用者
     */
    function release() external {
        uint256 amount = releasableAmount(msg.sender);
        require(amount > 0, "No tokens available for release");
        
        releasedAmount[msg.sender] += amount;
        
        require(token.transfer(msg.sender, amount), "Token transfer failed");
        
        emit TokensReleased(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev 为指定受益人释放代币
     * @param beneficiary 受益人地址
     */
    function releaseFor(address beneficiary) external {
        uint256 amount = releasableAmount(beneficiary);
        require(amount > 0, "No tokens available for release");
        
        releasedAmount[beneficiary] += amount;
        
        require(token.transfer(beneficiary, amount), "Token transfer failed");
        
        emit TokensReleased(beneficiary, amount, block.timestamp);
    }
    
    // ========== 管理员函数 ==========
    
    /**
     * @dev 添加新的受益人（仅限所有者）
     * @param beneficiary 受益人地址
     * @param amount 分配数量
     */
    function addBeneficiary(address beneficiary, uint256 amount) external onlyOwner {
        require(beneficiary != address(0), "Beneficiary address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(totalAllocation[beneficiary] == 0, "Beneficiary already exists");
        
        totalAllocation[beneficiary] = amount;
        
        emit BeneficiaryAdded(beneficiary, amount, block.timestamp);
    }
    
    /**
     * @dev 紧急提取代币（仅限所有者）
     * @param amount 提取数量
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(token.transfer(owner(), amount), "Token transfer failed");
    }
    
    // ========== 查询函数 ==========
    
    /**
     * @dev 获取合约中的代币余额
     * @return 代币余额
     */
    function contractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev 获取受益人信息
     * @param beneficiary 受益人地址
     * @return total 总分配量
     * @return released 已释放量
     * @return releasable 当前可释放量
     */
    function getBeneficiaryInfo(address beneficiary) 
        external 
        view 
        returns (uint256 total, uint256 released, uint256 releasable) 
    {
        total = totalAllocation[beneficiary];
        released = releasedAmount[beneficiary];
        releasable = releasableAmount(beneficiary);
    }
    
    /**
     * @dev 获取时间信息
     * @return deployTime 部署时间
     * @return cliffEnd 悬崖期结束时间
     * @return vestingEnd 归属期结束时间
     * @return currentTime 当前时间
     */
    function getTimeInfo() 
        external 
        view 
        returns (uint256 deployTime, uint256 cliffEnd, uint256 vestingEnd, uint256 currentTime) 
    {
        deployTime = deployTimestamp;
        cliffEnd = cliffTimestamp;
        vestingEnd = vestingEndTimestamp;
        currentTime = block.timestamp;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Oracle
 * @dev LaunchPad Meme Token TWAP Oracle 合约
 * 实现时间加权平均价格(TWAP)计算功能
 * 
 * 核心功能：
 * 1. 价格更新和存储
 * 2. TWAP (Time-Weighted Average Price) 计算
 * 3. 权限管理和安全控制
 * 4. 紧急操作机制
 */
contract Oracle {
    
    // ============ 事件定义 ============
    
    // 价格更新事件：记录价格变化的时间戳、新价格和累积价格
    event PriceUpdated(uint256 indexed timestamp, uint256 price, uint256 cumulativePrice);
    
    // TWAP计算事件：记录计算的时间窗口和结果
    event TWAPCalculated(uint256 window, uint256 twap);
    
    // 合约暂停事件：记录暂停操作和操作者
    event Paused(address indexed account);
    
    // 合约恢复事件：记录恢复操作和操作者
    event Unpaused(address indexed account);
    
    // ============ 状态变量 ============
    
    // 合约暂停状态：true表示暂停，false表示正常运行
    bool public paused;
    
    // 合约所有者地址：拥有最高权限的管理员
    address public owner;
    
    // 默认TWAP计算窗口：3600秒 = 1小时
    uint256 public constant DEFAULT_TWAP_WINDOW = 3600;
    
    // 最大价格变化百分比：50%，防止价格剧烈波动
    uint256 public constant MAX_PRICE_CHANGE = 50;
    
    // ============ 数据结构 ============
    
    /**
     * @dev 价格点数据结构
     * 用于存储价格更新的完整信息
     */
    struct PricePoint {
        uint256 timestamp;        // 价格更新的时间戳
        uint256 price;            // 当前价格（以wei为单位）
        uint256 cumulativePrice;  // 累积价格（用于TWAP计算）
        uint256 cumulativeTime;   // 累积时间（用于TWAP计算）
    }
    
    // ============ 存储变量 ============
    
    // 最新的价格点信息
    PricePoint public latestPricePoint;
    
    // 授权更新者映射：地址 => 是否有更新权限
    mapping(address => bool) public authorizedUpdaters;
    
    // ============ 修饰符 ============
    
    /**
     * @dev 仅所有者修饰符
     * 确保只有合约所有者可以调用特定函数
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Oracle: caller is not the owner");
        _; // 继续执行函数体
    }
    
    /**
     * @dev 仅授权用户修饰符
     * 确保只有授权的更新者或所有者可以调用特定函数
     */
    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner, "Oracle: caller is not authorized");
        _; // 继续执行函数体
    }
    
    /**
     * @dev 合约未暂停修饰符
     * 确保合约在正常运行状态下才能执行操作
     */
    modifier whenNotPaused() {
        require(!paused, "Oracle: paused");
        _; // 继续执行函数体
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数
     * 初始化合约状态和设置部署者为所有者
     */
    constructor() {
        // 设置部署者为合约所有者
        owner = msg.sender;
        
        // 将部署者添加为授权更新者
        authorizedUpdaters[msg.sender] = true;
        
        // 初始化价格点结构
        latestPricePoint = PricePoint({
            timestamp: block.timestamp,  // 当前区块时间戳
            price: 0,                    // 初始价格为0
            cumulativePrice: 0,          // 初始累积价格为0
            cumulativeTime: 0            // 初始累积时间为0
        });
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 更新价格函数
     * @param _price 新价格（以wei为单位）
     * 
     * 功能：
     * 1. 验证价格有效性
     * 2. 检查价格变化幅度
     * 3. 计算累积价格和时间
     * 4. 更新价格点信息
     * 5. 触发价格更新事件
     */
    function updatePrice(uint256 _price) external onlyAuthorized whenNotPaused {
        // 验证价格必须大于0
        require(_price > 0, "Oracle: price must be greater than 0");
        
        // 获取当前时间戳
        uint256 currentTime = block.timestamp;
        
        // 计算距离上次价格更新的时间间隔
        uint256 timeElapsed = currentTime - latestPricePoint.timestamp;
        
        // 检查价格变化幅度（防止价格操纵）
        if (latestPricePoint.price > 0) {
            // 计算价格变化的绝对值
            uint256 priceChange = _price > latestPricePoint.price ? 
                _price - latestPricePoint.price : 
                latestPricePoint.price - _price;
            
            // 计算价格变化百分比
            uint256 changePercentage = (priceChange * 100) / latestPricePoint.price;
            
            // 确保价格变化不超过最大限制
            require(changePercentage <= MAX_PRICE_CHANGE, "Oracle: price change too large");
        }
        
        // 计算新的累积价格：原累积价格 + (原价格 × 时间间隔)
        uint256 newCumulativePrice = latestPricePoint.cumulativePrice + 
            (latestPricePoint.price * timeElapsed);
        
        // 计算新的累积时间：原累积时间 + 时间间隔
        uint256 newCumulativeTime = latestPricePoint.cumulativeTime + timeElapsed;
        
        // 更新价格点信息
        latestPricePoint = PricePoint({
            timestamp: currentTime,           // 更新时间戳
            price: _price,                    // 更新价格
            cumulativePrice: newCumulativePrice, // 更新累积价格
            cumulativeTime: newCumulativeTime    // 更新累积时间
        });
        
        // 触发价格更新事件
        emit PriceUpdated(currentTime, _price, newCumulativePrice);
    }
    
    /**
     * @dev 获取指定时间窗口的TWAP
     * @param _window 时间窗口（秒）
     * @return TWAP价格
     * 
     * TWAP计算公式：累积价格 / 累积时间
     * 这样可以平滑价格波动，提供更稳定的价格参考
     */
    function getTWAP(uint256 _window) public view returns (uint256) {
        // 验证时间窗口必须大于0
        require(_window > 0, "Oracle: window must be greater than 0");
        
        // 确保有价格数据可用
        require(latestPricePoint.price > 0, "Oracle: no price data available");
        
        // 获取当前时间戳
        uint256 currentTime = block.timestamp;
        
        // 计算时间窗口的起始时间
        uint256 windowStart = currentTime - _window;
        
        // 如果窗口开始时间早于最新价格点时间，直接返回最新价格
        if (windowStart >= latestPricePoint.timestamp) {
            return latestPricePoint.price;
        }
        
        // 初始化窗口内的累积价格和时间
        uint256 windowCumulativePrice = latestPricePoint.cumulativePrice;
        uint256 windowCumulativeTime = latestPricePoint.cumulativeTime;
        
        // 如果窗口开始时间在累积时间范围内，需要调整计算
        if (windowStart > latestPricePoint.timestamp - latestPricePoint.cumulativeTime) {
            // 计算需要减去的时间
            uint256 timeToSubtract = latestPricePoint.timestamp - windowStart;
            
            // 调整累积时间
            windowCumulativeTime = timeToSubtract;
            
            // 调整累积价格
            windowCumulativePrice = latestPricePoint.price * timeToSubtract;
        }
        
        // 确保有足够的数据进行TWAP计算
        require(windowCumulativeTime > 0, "Oracle: insufficient data for TWAP calculation");
        
        // 计算TWAP：累积价格 / 累积时间
        uint256 twap = windowCumulativePrice / windowCumulativeTime;
        
        // 返回计算结果
        return twap;
    }
    
    /**
     * @dev 获取默认时间窗口的TWAP
     * @return 默认TWAP价格
     * 
     * 便捷函数：使用预定义的1小时窗口计算TWAP
     */
    function getDefaultTWAP() external view returns (uint256) {
        return getTWAP(DEFAULT_TWAP_WINDOW);
    }
    
    /**
     * @dev 获取最新价格
     * @return 最新价格
     * 
     * 简单查询函数：返回最近一次更新的价格
     */
    function getLatestPrice() external view returns (uint256) {
        return latestPricePoint.price;
    }
    
    /**
     * @dev 获取完整的价格点信息
     * @return 价格点结构
     * 
     * 返回包含时间戳、价格、累积价格和累积时间的完整信息
     */
    function getLatestPricePoint() external view returns (PricePoint memory) {
        return latestPricePoint;
    }
    
    // ============ 管理功能 ============
    
    /**
     * @dev 添加授权更新者
     * @param _updater 要授权的更新者地址
     * 
     * 只有合约所有者可以调用此函数
     */
    function addAuthorizedUpdater(address _updater) external onlyOwner {
        // 验证地址不为零地址
        require(_updater != address(0), "Oracle: invalid address");
        
        // 将地址标记为授权更新者
        authorizedUpdaters[_updater] = true;
    }
    
    /**
     * @dev 移除授权更新者
     * @param _updater 要移除授权的更新者地址
     * 
     * 只有合约所有者可以调用此函数
     */
    function removeAuthorizedUpdater(address _updater) external onlyOwner {
        // 将地址标记为非授权更新者
        authorizedUpdaters[_updater] = false;
    }
    
    /**
     * @dev 暂停合约
     * 
     * 暂停后，只有所有者可以执行紧急操作
     * 其他所有操作都会被阻止
     */
    function pause() external onlyOwner {
        // 设置暂停状态
        paused = true;
        
        // 触发暂停事件
        emit Paused(msg.sender);
    }
    
    /**
     * @dev 恢复合约
     * 
     * 恢复后，合约恢复正常运行状态
     */
    function unpause() external onlyOwner {
        // 清除暂停状态
        paused = false;
        
        // 触发恢复事件
        emit Unpaused(msg.sender);
    }
    
    /**
     * @dev 转移所有权
     * @param _newOwner 新的所有者地址
     * 
     * 转移合约的所有权给新地址
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        // 验证新所有者地址不为零地址
        require(_newOwner != address(0), "Oracle: invalid new owner");
        
        // 转移所有权
        owner = _newOwner;
    }
    
    /**
     * @dev 紧急更新价格（仅所有者）
     * @param _price 新价格
     * 
     * 紧急情况下，所有者可以绕过价格变化限制直接更新价格
     * 此函数不受暂停状态影响
     */
    function emergencyUpdatePrice(uint256 _price) external onlyOwner {
        // 验证价格必须大于0
        require(_price > 0, "Oracle: price must be greater than 0");
        
        // 获取当前时间戳
        uint256 currentTime = block.timestamp;
        
        // 计算距离上次价格更新的时间间隔
        uint256 timeElapsed = currentTime - latestPricePoint.timestamp;
        
        // 计算新的累积价格（与正常更新逻辑相同）
        uint256 newCumulativePrice = latestPricePoint.cumulativePrice + 
            (latestPricePoint.price * timeElapsed);
        
        // 计算新的累积时间
        uint256 newCumulativeTime = latestPricePoint.cumulativeTime + timeElapsed;
        
        // 更新价格点信息
        latestPricePoint = PricePoint({
            timestamp: currentTime,           // 更新时间戳
            price: _price,                    // 更新价格
            cumulativePrice: newCumulativePrice, // 更新累积价格
            cumulativeTime: newCumulativeTime    // 更新累积时间
        });
        
        // 触发价格更新事件
        emit PriceUpdated(currentTime, _price, newCumulativePrice);
    }
}
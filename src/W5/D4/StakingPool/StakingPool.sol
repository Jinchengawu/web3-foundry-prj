/**
 * @title StakingPool 合约说明
 * @dev 编写 StakingPool 合约，实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚钱 KK Token。
 * 其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。
 * 
 * （加分项）用户质押 ETH 的可存入的一个借贷市场赚取利息.
 * 
 * 参考思路：找到 借贷市场 进行一笔存款，然后查看调用的方法，在 Stake 中集成该方法
 * 
 * 下面是合约接口信息
 */

// 声明 Solidity 版本，使用 0.8.0 或更高版本
pragma solidity ^0.8.0;

// 导入自定义的接口合约
import {IToken, IStaking} from './Staking_interface.sol';  // 导入 KK Token 和质押接口
import {ILendingMarket} from './ILendingMarket.sol';        // 导入借贷市场接口

// 导入 OpenZeppelin 标准库合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";           // ERC20 代币标准
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";    // 防重入攻击保护
import "@openzeppelin/contracts/utils/Pausable.sol";           // 可暂停功能
import "@openzeppelin/contracts/access/Ownable.sol";              // 所有权管理

/**
 * @title Staking Pool Contract
 * @dev 实现质押 ETH 赚取 KK Token 的合约
 * 继承多个接口和合约：IStaking（质押接口）、ReentrancyGuard（防重入）、Pausable（可暂停）、Ownable（所有权）
 */
contract KKStaking is IStaking, ReentrancyGuard, Pausable, Ownable {
    // KK Token 合约地址，使用 immutable 关键字确保部署后不可更改
    IToken public immutable kkToken;
    
    // 借贷市场合约地址（例如 Aave 或 Compound），用于赚取额外利息
    ILendingMarket public lendingMarket;
    
    // 每个区块产出的 KK Token 数量，使用 constant 关键字定义常量
    // 10 * 10^18 表示 10 个 KK Token（假设 KK Token 有 18 位小数）
    uint256 public constant REWARD_PER_BLOCK = 10 * 10**18; // 10 KK Token
    
    // 质押信息结构体，存储每个用户的质押相关信息
    struct StakingInfo {
        uint256 stakedAmount;          // 质押的 ETH 数量
        uint256 rewardDebt;            // 奖励债务（用于计算收益，防止重复计算）
        uint256 lastUpdateTime;        // 最后更新时间（用于计算质押时长）
        uint256 lendingMarketBalance;  // 在借贷市场的余额（用于跟踪借贷市场中的资金）
    }
    
    // 用户质押信息映射，将用户地址映射到其质押信息
    mapping(address => StakingInfo) public stakingUsers;
    
    // 总质押量，记录所有用户质押的 ETH 总量
    uint256 public totalStaked;
    
    // 累计每单位质押的奖励，用于公平分配奖励
    // 使用 1e18 精度来避免浮点数计算误差
    uint256 public accRewardPerShare;
    
    // 最后更新奖励的区块时间，用于计算时间间隔
    uint256 public lastRewardTime;
    
    // 定义事件，用于记录重要操作和前端监听
    event Staked(address indexed user, uint256 amount);           // 质押事件
    event Unstaked(address indexed user, uint256 amount);         // 解质押事件
    event RewardClaimed(address indexed user, uint256 amount);    // 领取奖励事件
    event LendingMarketUpdated(address indexed oldMarket, address indexed newMarket); // 借贷市场更新事件
    
    /**
     * @dev 构造函数，在合约部署时执行一次
     * @param _token KK Token 合约地址
     */
    constructor(IToken _token) {
        // 验证传入的代币地址是否有效（不能是零地址）
        require(address(_token) != address(0), "Invalid token address");
        // 设置 KK Token 合约地址
        kkToken = _token;
        // 初始化最后奖励更新时间
        lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev 质押 ETH 到合约的主函数
     * 使用 payable 关键字允许接收 ETH
     * 使用 override 关键字重写接口中的方法
     * 使用 nonReentrant 修饰符防止重入攻击
     * 使用 whenNotPaused 修饰符确保合约未暂停
     */
    function stake() external payable override nonReentrant whenNotPaused {
        // 验证质押数量必须大于 0
        require(msg.value > 0, "Stake amount must be greater than 0");
        
        // 更新奖励计算（必须在质押前更新，确保奖励计算准确）
        _updateReward();
        
        // 更新用户质押信息
        StakingInfo storage userInfo = stakingUsers[msg.sender];  // 获取用户质押信息存储引用
        userInfo.stakedAmount += msg.value;                       // 增加质押数量
        userInfo.lastUpdateTime = block.timestamp;                // 更新最后操作时间
        
        // 更新总质押量
        totalStaked += msg.value;
        
        // 将 ETH 存入借贷市场（如果已设置借贷市场地址）
        if (address(lendingMarket) != address(0)) {
            _depositToLendingMarket(msg.value);                   // 调用内部函数存入借贷市场
            userInfo.lendingMarketBalance += msg.value;            // 更新借贷市场余额记录
        }
        
        // 触发质押事件，供前端监听
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev 赎回质押的 ETH 的主函数
     * @param amount 赎回数量
     * 使用 override 关键字重写接口中的方法
     * 使用 nonReentrant 修饰符防止重入攻击
     * 使用 whenNotPaused 修饰符确保合约未暂停
     */
    function unstake(uint256 amount) external override nonReentrant whenNotPaused {
        // 验证赎回数量必须大于 0
        require(amount > 0, "Unstake amount must be greater than 0");
        
        // 获取用户质押信息
        StakingInfo storage userInfo = stakingUsers[msg.sender];
        // 验证用户质押数量是否足够
        require(userInfo.stakedAmount >= amount, "Insufficient staked amount");
        
        // 更新奖励计算（必须在解质押前更新）
        _updateReward();
        
        // 从借贷市场提取 ETH（如果已设置借贷市场）
        if (address(lendingMarket) != address(0)) {
            _withdrawFromLendingMarket(amount);                    // 调用内部函数从借贷市场提取
            userInfo.lendingMarketBalance -= amount;               // 更新借贷市场余额记录
        }
        
        // 更新用户质押信息
        userInfo.stakedAmount -= amount;                           // 减少质押数量
        userInfo.lastUpdateTime = block.timestamp;                 // 更新最后操作时间
        
        // 更新总质押量
        totalStaked -= amount;
        
        // 转账 ETH 给用户，使用 call 方法进行安全的 ETH 转账
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        // 验证转账是否成功
        require(success, "ETH transfer failed");
        
        // 触发解质押事件
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取 KK Token 收益的主函数
     * 使用 override 关键字重写接口中的方法
     * 使用 nonReentrant 修饰符防止重入攻击
     * 使用 whenNotPaused 修饰符确保合约未暂停
     */
    function claim() external override nonReentrant whenNotPaused {
        // 更新奖励计算（必须在领取前更新）
        _updateReward();
        
        // 获取用户质押信息
        StakingInfo storage userInfo = stakingUsers[msg.sender];
        // 计算待领取的奖励
        uint256 pendingReward = _pendingReward(msg.sender);
        
        // 验证是否有奖励可领取
        require(pendingReward > 0, "No reward to claim");
        
        // 更新奖励债务，防止重复计算奖励
        userInfo.rewardDebt = userInfo.stakedAmount * accRewardPerShare / 1e18;
        
        // 铸造 KK Token 给用户
        kkToken.mint(msg.sender, pendingReward);
        
        // 触发领取奖励事件
        emit RewardClaimed(msg.sender, pendingReward);
    }
    
    /**
     * @dev 获取质押的 ETH 数量的查询函数
     * @param account 质押账户地址
     * @return 质押的 ETH 数量
     * 使用 override 关键字重写接口中的方法
     * 使用 view 关键字表示只读函数，不消耗 gas
     */
    function balanceOf(address account) external view override returns (uint256) {
        // 返回指定账户的质押数量
        return stakingUsers[account].stakedAmount;
    }
    
    /**
     * @dev 获取待领取的 KK Token 收益的查询函数
     * @param account 质押账户地址
     * @return 待领取的 KK Token 收益
     * 使用 override 关键字重写接口中的方法
     * 使用 view 关键字表示只读函数，不消耗 gas
     */
    function earned(address account) external view override returns (uint256) {
        // 调用内部函数计算待领取的奖励
        return _pendingReward(account);
    }
    
    /**
     * @dev 更新奖励的内部函数
     * 使用 internal 关键字表示只能在合约内部调用
     * 这个函数负责更新全局奖励状态
     */
    function _updateReward() internal {
        // 如果当前时间不晚于最后奖励时间，则无需更新
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        
        // 如果有质押，则计算并更新奖励
        if (totalStaked > 0) {
            // 计算时间间隔
            uint256 timePassed = block.timestamp - lastRewardTime;
            // 计算这段时间内产生的总奖励
            uint256 reward = timePassed * REWARD_PER_BLOCK;
            // 更新累计每单位质押的奖励，使用 1e18 精度避免浮点数误差
            accRewardPerShare += reward * 1e18 / totalStaked;
        }
        
        // 更新最后奖励时间
        lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev 计算待领取的奖励的内部函数
     * @param account 用户地址
     * @return 待领取的奖励数量
     * 使用 internal view 关键字表示内部只读函数
     */
    function _pendingReward(address account) internal view returns (uint256) {
        // 获取用户质押信息
        StakingInfo storage userInfo = stakingUsers[account];
        uint256 stakedAmount = userInfo.stakedAmount;
        
        // 如果用户没有质押，则没有奖励
        if (stakedAmount == 0) {
            return 0;
        }
        
        // 获取当前累计每单位质押的奖励
        uint256 currentAccRewardPerShare = accRewardPerShare;
        
        // 如果当前时间晚于最后奖励时间且有质押，则计算额外奖励
        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            // 计算时间间隔
            uint256 timePassed = block.timestamp - lastRewardTime;
            // 计算这段时间内产生的总奖励
            uint256 reward = timePassed * REWARD_PER_BLOCK;
            // 计算当前累计每单位质押的奖励
            currentAccRewardPerShare += reward * 1e18 / totalStaked;
        }
        
        // 计算用户应得的奖励：质押数量 * 累计奖励 - 已计算的奖励债务
        return stakedAmount * currentAccRewardPerShare / 1e18 - userInfo.rewardDebt;
    }
    
    /**
     * @dev 将 ETH 存入借贷市场的内部函数
     * @param amount 存入数量
     * 使用 internal 关键字表示只能在合约内部调用
     */
    function _depositToLendingMarket(uint256 amount) internal {
        // 这里需要根据具体的借贷市场合约来实现
        // 例如 Aave 的 deposit 方法或 Compound 的 mint 方法
        // 暂时使用简单的转账，实际使用时需要调用借贷市场的具体方法
        
        // 示例：如果借贷市场有 deposit 方法
        // ILendingMarket(lendingMarket).deposit{value: amount}();
        
        // 或者直接转账到借贷市场
        (bool success, ) = payable(lendingMarket).call{value: amount}("");
        // 验证转账是否成功
        require(success, "Failed to deposit to lending market");
    }
    
    /**
     * @dev 从借贷市场提取 ETH 的内部函数
     * @param amount 提取数量
     * 使用 internal 关键字表示只能在合约内部调用
     */
    function _withdrawFromLendingMarket(uint256 amount) internal {
        // 这里需要根据具体的借贷市场合约来实现
        // 例如 Aave 的 withdraw 方法或 Compound 的 redeem 方法
        
        // 示例：如果借贷市场有 withdraw 方法
        // ILendingMarket(lendingMarket).withdraw(amount);
        
        // 或者从借贷市场接收 ETH
        // 实际实现需要根据借贷市场的具体接口
        // 注意：这里需要实现具体的提取逻辑
    }
    
    /**
     * @dev 设置借贷市场地址的管理函数
     * @param _lendingMarket 新的借贷市场地址
     * 使用 external 关键字表示只能从合约外部调用
     * 使用 onlyOwner 修饰符确保只有合约所有者可以调用
     */
    function setLendingMarket(address _lendingMarket) external onlyOwner {
        // 验证新地址是否有效
        require(_lendingMarket != address(0), "Invalid lending market address");
        // 保存旧地址用于事件记录
        address oldMarket = address(lendingMarket);
        // 更新借贷市场地址
        lendingMarket = ILendingMarket(_lendingMarket);
        // 触发借贷市场更新事件
        emit LendingMarketUpdated(oldMarket, _lendingMarket);
    }
    
    /**
     * @dev 暂停合约的管理函数
     * 使用 external 关键字表示只能从合约外部调用
     * 使用 onlyOwner 修饰符确保只有合约所有者可以调用
     */
    function pause() external onlyOwner {
        // 调用继承的 _pause 函数暂停合约
        _pause();
    }
    
    /**
     * @dev 恢复合约的管理函数
     * 使用 external 关键字表示只能从合约外部调用
     * 使用 onlyOwner 修饰符确保只有合约所有者可以调用
     */
    function unpause() external onlyOwner {
        // 调用继承的 _unpause 函数恢复合约
        _unpause();
    }
    
    /**
     * @dev 紧急提取函数（仅限合约所有者）
     * 使用 external 关键字表示只能从合约外部调用
     * 使用 onlyOwner 修饰符确保只有合约所有者可以调用
     * 用于紧急情况下提取合约中的所有 ETH
     */
    function emergencyWithdraw() external onlyOwner {
        // 获取合约的 ETH 余额
        uint256 balance = address(this).balance;
        // 如果有余额，则提取给所有者
        if (balance > 0) {
            // 使用 call 方法安全地转账 ETH 给所有者
            (bool success, ) = payable(owner()).call{value: balance}("");
            // 验证转账是否成功
            require(success, "Emergency withdrawal failed");
        }
    }
    
    /**
     * @dev 接收 ETH 的回退函数
     * 使用 receive 关键字定义接收 ETH 的函数
     * 使用 external payable 关键字表示可以接收 ETH
     * 这个函数允许合约接收 ETH 转账
     */
    receive() external payable {}
    
    /**
     * @dev 获取合约 ETH 余额的查询函数
     * @return 合约当前的 ETH 余额
     * 使用 external view 关键字表示外部只读函数
     */
    function getContractBalance() external view returns (uint256) {
        // 返回合约的 ETH 余额
        return address(this).balance;
    }
    
    /**
     * @dev 获取用户总收益的查询函数（包括借贷市场收益）
     * @param account 用户地址
     * @return 用户的总收益（质押奖励 + 借贷市场收益）
     * 使用 external view 关键字表示外部只读函数
     */
    function getUserTotalReward(address account) external view returns (uint256) {
        // 获取用户质押信息
        StakingInfo storage userInfo = stakingUsers[account];
        // 计算质押奖励
        uint256 stakingReward = _pendingReward(account);
        // 初始化借贷市场收益为 0
        uint256 lendingReward = 0;
        
        // 这里可以添加从借贷市场获取收益的逻辑
        // 例如：lendingReward = ILendingMarket(lendingMarket).getUserReward(account);
        
        // 返回总收益
        return stakingReward + lendingReward;
    }
}
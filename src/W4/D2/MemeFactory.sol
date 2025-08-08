// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Meme
 * @dev Meme ERC20 代币合约
 */
contract Meme is ERC20, Ownable {
    uint256 public totalSupplyLimit;
    uint256 public perMint;
    uint256 public price;
    uint256 public mintedAmount;
    bool public initialized;
    
    constructor() ERC20("Meme Token", "MEME") Ownable(msg.sender) {
        // 空构造函数，用于代理模式
    }
    
    /**
     * @dev 初始化函数，用于代理合约
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _owner
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;
        
        // 设置所有者
        _transferOwnership(_owner);
        
        // 设置其他属性
        totalSupplyLimit = _totalSupply;
        perMint = _perMint;
        price = _price;
    }
    
    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(mintedAmount + amount <= totalSupplyLimit, "Exceeds total supply");
        require(amount == perMint, "Invalid mint amount");
        mintedAmount += amount;
        _mint(to, amount);
    }
    
    /**
     * @dev 检查是否还可以铸造
     */
    function canMint() external view returns (bool) {
        return mintedAmount + perMint <= totalSupplyLimit;
    }
    
    /**
     * @dev 获取剩余可铸造数量
     */
    function remainingSupply() external view returns (uint256) {
        return totalSupplyLimit - mintedAmount;
    }
}

/**
 * @title MemeFactory
 * @dev Meme 工厂合约，使用最小代理模式部署 Meme 代币
 */
contract MemeFactory is Ownable {
    // Meme 实现合约地址
    address public immutable memeImplementation;
    
    // 费用分配比例 (1% = 100)
    uint256 public constant PROJECT_FEE_RATIO = 500; // 5%
    uint256 public constant CREATOR_FEE_RATIO = 9400; // 94%
    uint256 public constant FEE_DENOMINATOR = 10000; // 100%
    
    // 存储 Meme 信息
    struct MemeInfo {
        address creator;
        uint256 totalSupply;
        uint256 perMint;
        uint256 price;
        bool exists;
    }
    
    // token地址 => Meme信息
    mapping(address => MemeInfo) public memeInfos;
    
    // 事件
    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );
    
    event FeesDistributed(
        address indexed token,
        address indexed creator,
        uint256 creatorFee,
        uint256 projectFee
    );
    
    constructor() Ownable(msg.sender) {
        // 部署 Meme 实现合约
        memeImplementation = address(new Meme());
    }
    
    /**
     * @dev 部署新的 Meme 代币
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造数量
     * @param price 每个代币价格（wei）
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        require(price > 0, "Price must be greater than 0");
        
        // 使用最小代理模式部署
        address memeToken = Clones.clone(memeImplementation);
        
        // 初始化代理合约 - 工厂合约作为所有者
        Meme(memeToken).initialize(
            string(abi.encodePacked("Meme ", symbol)),
            symbol,
            totalSupply,
            perMint,
            price,
            address(this)
        );
        
        // 存储 Meme 信息
        memeInfos[memeToken] = MemeInfo({
            creator: msg.sender,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            exists: true
        });
        
        emit MemeDeployed(memeToken, msg.sender, symbol, totalSupply, perMint, price);
        
        return memeToken;
    }
    
    /**
     * @dev 铸造 Meme 代币
     * @param tokenAddr Meme 代币地址
     */
    function mintMeme(address tokenAddr) external payable {
        MemeInfo memory info = memeInfos[tokenAddr];
        require(info.exists, "Meme does not exist");
        
        Meme memeToken = Meme(tokenAddr);
        require(memeToken.canMint(), "Cannot mint more tokens");
        
        uint256 cost = info.price * info.perMint;
        require(msg.value >= cost, "Insufficient payment");
        
        // 铸造代币 - 工厂合约作为所有者调用
        memeToken.mint(msg.sender, info.perMint);
        
        // 分配费用
        uint256 creatorFee = (cost * CREATOR_FEE_RATIO) / FEE_DENOMINATOR;
        uint256 projectFee = cost - creatorFee;
        
        // 发送费用给创建者
        if (creatorFee > 0) {
            (bool success1, ) = info.creator.call{value: creatorFee}("");
            require(success1, "Failed to send creator fee");
        }
        
        // 发送费用给项目方
        if (projectFee > 0) {
            (bool success2, ) = owner().call{value: projectFee}("");
            // 如果发送失败，将费用留在合约中
            if (!success2) {
                // 可以选择记录日志或采取其他措施
            }
        }
        
        // 退还多余的 ETH
        uint256 refund = msg.value - cost;
        if (refund > 0) {
            (bool success3, ) = msg.sender.call{value: refund}("");
            require(success3, "Failed to refund excess ETH");
        }
        
        emit MemeMinted(tokenAddr, msg.sender, info.perMint, cost);
        emit FeesDistributed(tokenAddr, info.creator, creatorFee, projectFee);
    }
    
    /**
     * @dev 获取 Meme 信息
     * @param tokenAddr Meme 代币地址
     */
    function getMemeInfo(address tokenAddr) external view returns (MemeInfo memory) {
        return memeInfos[tokenAddr];
    }
    
    /**
     * @dev 检查地址是否为有效的 Meme 代币
     * @param tokenAddr 代币地址
     */
    function isMeme(address tokenAddr) external view returns (bool) {
        return memeInfos[tokenAddr].exists;
    }
    
    /**
     * @dev 获取铸造费用
     * @param tokenAddr Meme 代币地址
     */
    function getMintCost(address tokenAddr) external view returns (uint256) {
        MemeInfo memory info = memeInfos[tokenAddr];
        require(info.exists, "Meme does not exist");
        return info.price * info.perMint;
    }
    
    /**
     * @dev 紧急提取 ETH（仅限所有者）
     */
    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Failed to withdraw ETH");
    }
}
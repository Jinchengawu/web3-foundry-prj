pragma solidity ^0.8.0;

/**
实现一个 AirdopMerkleNFTMarket 合约(假定 Token、NFT、AirdopMerkleNFTMarket 都是同一个开发者开发)，功能如下：

基于 Merkel 树验证某用户是否在白名单中
在白名单中的用户可以使用上架（和之前的上架逻辑一致）指定价格的优惠 50% 的Token 来购买 NFT， Token 需支持 permit 授权。
要求使用 multicall( delegateCall 方式) 一次性调用两个方法：

permitPrePay() : 调用token的 permit 进行授权
claimNFT() : 通过默克尔树验证白名单，并利用 permitPrePay 的授权，转入 token 转出 NFT 。
请贴出你的代码 github ，代码需包含合约，multicall 调用封装，Merkel 树的构建以及测试用例。



 */

import {NFTMarketV2} from "../../W3/D5/NFTMarketV2.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TokenV3} from "../../W3/D5/TokenV3.sol";

contract AirdopMerkleNFTMarket is NFTMarketV2 {
    // Token 合约地址
    address public immutable tokenAddress;
    // Merkle 树根
    bytes32 public immutable merkleRoot;
    // 优惠折扣比例 (50% = 5000 / 10000)
    uint256 public constant DISCOUNT_RATIO = 5000;
    uint256 public constant BASIS_POINTS = 10000;
    
    // 记录用户已领取的 NFT 数量
    mapping(address => uint256) public claimedAmounts;
    
    // 事件定义
    event NFTClaimed(address indexed account, string indexed listingId, uint256 originalPrice, uint256 discountedPrice);
    event PermitPrePayExecuted(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address _paymentTokenAddress,
        bytes32 _merkleRoot
    ) NFTMarketV2(_paymentTokenAddress) {
        tokenAddress = _paymentTokenAddress;
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev 验证 Merkle 证明
     * @param account 用户地址
     * @param maxAmount 用户最大可领取数量
     * @param merkleProof Merkle 证明
     * @return 验证是否通过
     */
    function verifyMerkleProof(
        address account,
        uint256 maxAmount,
        bytes32[] calldata merkleProof
    ) public view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(account, maxAmount));
        return MerkleProof.verify(merkleProof, merkleRoot, node);
    }

    /**
     * @dev 调用 token 的 permit 进行授权
     * @param owner token 持有者地址
     * @param spender 被授权者地址
     * @param value 授权金额
     * @param deadline 签名过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // 调用 token 的 permit 函数
        TokenV3(tokenAddress).permit(owner, spender, value, deadline, v, r, s);
        
        emit PermitPrePayExecuted(owner, spender, value);
    }

    /**
     * @dev 通过 Merkle 树验证白名单并购买 NFT
     * @param listingId 上架 ID
     * @param maxAmount 用户最大可领取数量
     * @param merkleProof Merkle 证明
     */
    function claimNFT(
        string memory listingId,
        uint256 maxAmount,
        bytes32[] calldata merkleProof
    ) public {
        // 验证 Merkle 证明
        require(
            verifyMerkleProof(msg.sender, maxAmount, merkleProof),
            "AirdopMerkleNFTMarket: Invalid merkle proof"
        );
        
        // 检查上架信息
        Listing storage listing = listings[listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        
        // 检查用户是否还有可领取数量
        uint256 claimedAmount = claimedAmounts[msg.sender];
        require(claimedAmount < maxAmount, "AirdopMerkleNFTMarket: already claimed maximum amount");
        
        // 计算优惠价格 (50% 折扣)
        uint256 discountedPrice = (listing.price * DISCOUNT_RATIO) / BASIS_POINTS;
        
        // 检查买家是否有足够的代币余额
        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= discountedPrice,
            "AirdopMerkleNFTMarket: insufficient token balance"
        );
        
        // 检查买家是否有足够的授权额度
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= discountedPrice,
            "AirdopMerkleNFTMarket: insufficient token allowance"
        );
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 更新用户已领取数量
        claimedAmounts[msg.sender]++;
        
        // 处理代币转账（买家 -> 卖家，使用优惠价格）
        IERC20(tokenAddress).transferFrom(msg.sender, listing.seller, discountedPrice);
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // 发出事件
        emit NFTSold(listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, discountedPrice);
        emit NFTClaimed(msg.sender, listingId, listing.price, discountedPrice);
    }

    /**
     * @dev 批量调用函数
     * @param data 要调用的函数数据数组
     * @return results 调用结果数组
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        require(data.length > 0, "AirdopMerkleNFTMarket: data is empty");
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "AirdopMerkleNFTMarket: delegatecall failed");
            results[i] = result;
        }
        
        return results;
    }

    /**
     * @dev 获取用户已领取的数量
     * @param account 用户地址
     * @return 已领取数量
     */
    function getClaimedAmount(address account) public view returns (uint256) {
        return claimedAmounts[account];
    }

    /**
     * @dev 计算优惠价格
     * @param originalPrice 原始价格
     * @return 优惠价格
     */
    function calculateDiscountedPrice(uint256 originalPrice) public pure returns (uint256) {
        return (originalPrice * DISCOUNT_RATIO) / BASIS_POINTS;
    }
}

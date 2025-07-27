/**

修改Token 购买 NFT NTFMarket 合约，添加功能 permitBuy() 
实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 。
白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 permitBuy() 函数，
在permitBuy()中判断时候是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。

要求：
有 Token 存款及 NFT 购买成功的测试用例
有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。

 */

pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTMarket} from "../../W2/D3/NFTMarket.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarketV2 is NFTMarket, EIP712 {
    // EIP-712 类型哈希，用于白名单购买签名验证
    bytes32 public constant PERMIT_BUY_TYPEHASH = 
        keccak256("PermitBuy(address buyer,uint256 listingId,uint256 deadline)");
    
    // 白名单用户 nonce 映射，用于防重放攻击
    mapping(address => uint256) public whitelistNonces;
    
    // 白名单管理员地址
    address public whitelistAdmin;
    
    // 错误定义
    error PermitBuyExpiredSignature(uint256 deadline);
    error PermitBuyInvalidSigner(address signer, address admin);
    error PermitBuyInvalidBuyer(address expectedBuyer, address actualBuyer);
    error PermitBuyInvalidListingId(uint256 expectedListingId, uint256 actualListingId);
    error PermitBuyInsufficientBalance(address buyer, uint256 balance, uint256 required);
    error PermitBuyInsufficientAllowance(address buyer, uint256 allowance, uint256 required);
    
    // 事件定义
    event PermitBuyExecuted(address indexed buyer, uint256 indexed listingId, uint256 price, uint256 deadline);
    event WhitelistAdminChanged(address indexed oldAdmin, address indexed newAdmin);
    
    constructor(address _paymentTokenAddress) 
        NFTMarket(_paymentTokenAddress)
        EIP712("NFTMarketV2", "1") 
    {
        whitelistAdmin = msg.sender;
    }
    
    /**
     * @dev 通过离线签名授权进行白名单购买
     * @param buyer 购买者地址
     * @param listingId 上架ID
     * @param deadline 签名过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitBuy(
        address buyer,
        uint256 listingId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // 验证基本参数
        _validatePermitBuyParams(buyer, listingId, deadline);
        
        // 验证白名单购买签名
        _verifyPermitBuySignature(buyer, listingId, deadline, v, r, s);
        
        // 检查上架信息
        Listing storage listing = listings[listingId];
        require(listingId < nextListingId, "NFTMarketV2: listing id does not exist");
        require(listing.isActive, "NFTMarketV2: listing is not active");
        
        // 检查买家是否有足够的代币余额
        uint256 buyerBalance = paymentToken.balanceOf(buyer);
        if (buyerBalance < listing.price) {
            revert PermitBuyInsufficientBalance(buyer, buyerBalance, listing.price);
        }
        
        // 检查买家是否有足够的授权额度
        uint256 buyerAllowance = paymentToken.allowance(buyer, address(this));
        if (buyerAllowance < listing.price) {
            revert PermitBuyInsufficientAllowance(buyer, buyerAllowance, listing.price);
        }
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 处理代币转账（买家 -> 卖家）
        paymentToken.transferFrom(buyer, listing.seller, listing.price);
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, buyer, listing.tokenId);
        
        // 发出事件
        emit NFTSold(listingId, buyer, listing.seller, listing.nftContract, listing.tokenId, listing.price);
        emit PermitBuyExecuted(buyer, listingId, listing.price, deadline);
    }
    
    /**
     * @dev 设置白名单管理员地址
     * @param newAdmin 新的管理员地址
     */
    function setWhitelistAdmin(address newAdmin) public {
        require(msg.sender == whitelistAdmin, "NFTMarketV2: caller is not admin");
        require(newAdmin != address(0), "NFTMarketV2: new admin cannot be zero address");
        
        address oldAdmin = whitelistAdmin;
        whitelistAdmin = newAdmin;
        
        emit WhitelistAdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev 获取域分隔符（用于前端签名）
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
    
    /**
     * @dev 获取当前白名单 nonce（用于防重放攻击）
     */
    function getWhitelistNonce(address buyer) public view returns (uint256) {
        return whitelistNonces[buyer];
    }
    
    /**
     * @dev 验证白名单购买基本参数
     * @param buyer 购买者地址
     * @param listingId 上架ID
     * @param deadline 过期时间
     */
    function _validatePermitBuyParams(
        address buyer,
        uint256 listingId,
        uint256 deadline
    ) internal view {
        // 检查购买者地址是否有效
        require(buyer != address(0), "NFTMarketV2: buyer cannot be zero address");
        
        // 检查上架ID是否有效
        require(listingId < nextListingId, "NFTMarketV2: listing id does not exist");
        
        // 检查签名是否过期
        if (block.timestamp > deadline) {
            revert PermitBuyExpiredSignature(deadline);
        }
    }
    
    /**
     * @dev 验证白名单购买签名
     * @param buyer 购买者地址
     * @param listingId 上架ID
     * @param deadline 过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function _verifyPermitBuySignature(
        address buyer,
        uint256 listingId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        // 构建结构体哈希
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_BUY_TYPEHASH, buyer, listingId, deadline)
        );
        
        // 构建完整的 EIP-712 哈希
        bytes32 hash = _hashTypedDataV4(structHash);
        
        // 从签名中恢复签名者地址
        address signer = ecrecover(hash, v, r, s);
        
        // 验证签名者是否为白名单管理员
        if (signer != whitelistAdmin) {
            revert PermitBuyInvalidSigner(signer, whitelistAdmin);
        }
        
        // 增加 nonce 防止重放攻击
        whitelistNonces[buyer]++;
    }
    

}
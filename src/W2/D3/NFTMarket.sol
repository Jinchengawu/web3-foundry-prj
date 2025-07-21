pragma solidity ^0.8.0;
/***

编写一个简单的 NFTMarket 合约，使用自己发行的ERC20 
扩展 Token 来买卖 NFT， NFTMarket 的函数有：

list() : 实现上架功能，NFT 持有者可以设定一个价格
（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

实现ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，
在 tokensReceived 中实现NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。

 */
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarket {
    address public owner;
    mapping(uint256 => uint256) public tokenIdToPrice;
    IERC20 public paymentToken;
    ERC721 public nftContract;

    constructor(IERC20 _paymentToken, ERC721 _nftContract) {
        owner = msg.sender;
        paymentToken = _paymentToken;
        nftContract = _nftContract;
    }
    
    function list(uint256 tokenId, uint256 price) public returns(bool) {
        require(tokenIdToPrice[tokenId] == 0, "NFT is already listed");
        require(price > 0, "price is not enough");
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(nftContract.isApprovedForAll(msg.sender, address(this)), "NFT not approved");
        
        tokenIdToPrice[tokenId] = price;
        return true;
    }
    
    function buyNFT(uint256 tokenId, uint256 price) public returns(bool) {
        require(tokenIdToPrice[tokenId] != 0, "tokenId is not listed");
        require(price >= tokenIdToPrice[tokenId], "price is not enough");
        require(paymentToken.safeTransferFrom(msg.sender, address(this), price), "Token transfer failed");
        
        address seller = nftContract.ownerOf(tokenId);
        nftContract.safeTransferFrom(seller, msg.sender, tokenId);
        tokenIdToPrice[tokenId] = 0;
        
        return true;
    }
}
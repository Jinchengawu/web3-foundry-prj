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
import "@openzeppelin/contracts/token/ERC721.sol";

interface MYERC20  is ERC721{

}

contract NFTMarket {
  address public owner;
  mapping(address => uint256) public tokenIdToPrice;
  MYERC20 public MyERC20;

  constructor(MYERC20 memory _MyERC20) {

    owner = msg.sender;
    MyERC20 = _MyERC20;
  }
  function list(address NFTAddress, uint256 tokenId, uint256 price ) public returns(bool){
    require(tokenIdToPrice[tokenId] == 0,"NFT is already listed");
    require(price > 0,"price is not enough");

    tokenIdToPrice[tokenId] = price;

    return true;
  }
  function buyNFT(address NFTAddress, uint256 tokenId, uint256 price ) public returns(bool){
    require(tokenIdToPrice[tokenId] != 0,"tokenId is not listed");
    require(price>=tokenIdToPrice[tokenId],"price is not enough");
    tokenIdToPrice[tokenId] = 0;
    MyERC20.transferFrom(msg.sender, address(this), price);
    return true;
  }
}
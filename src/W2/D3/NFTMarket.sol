pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721.sol";

interface IERC721 is ERC721{

}

contract NFTMarket {
  address public owner;
  mapping(address => uint256) public tokenIdToPrice;
  mapping(address => mapping(address => uint256)) public NFTList;
  constructor(IERC721 memory NFTAddress) {

    owner = msg.sender;
    
  }
  function list(address NFTAddress, uint256 tokenId ) public returns(bool){

  }
}
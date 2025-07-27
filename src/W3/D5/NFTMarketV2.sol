/*
3.修改Token 购买 NFT NTFMarket 合约，添加功能 permitBuy() 
实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 
。白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，
传给 permitBuy() 函数，在permitBuy()中判断时候是经过许可的白名单用户，
如果是，才可以进行后续购买，否则 revert 。
*/

pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721V2} from "../../W2/D3/ERC721_Plus.sol";

contract NFTMarketV2 is ERC721V2 {
  constructor(string memory name, string memory symbol) ERC721V2(name, symbol) {}
  function permitBuy(address owner, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, tokenId, deadline));
    bytes32 hash = keccak256(abi.encodePacked(
      "\x19\x01",
      DOMAIN_SEPARATOR(),
      hashStruct
    ));
    address signer = ecrecover(hash, v, r, s);
  }


    /**
     * @dev 获取域分隔符（用于前端签名）
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("NFTMarketV2")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }
}
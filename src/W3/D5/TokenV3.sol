pragma solidity ^0.8.20;

/***

1.使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。
2.修改 TokenBank 存款合约 ,添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款, 
并在TokenBank前端 加入通过签名存款。

3.修改Token 购买 NFT NTFMarket 合约，添加功能 permitBuy() 
实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 
。白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，
传给 permitBuy() 函数，在permitBuy()中判断时候是经过许可的白名单用户，
如果是，才可以进行后续购买，否则 revert 。

解：
客户端：
1.客户端需要能够 构造交易签名；【私钥，交易信息】
合约：
1.token需要支持permit进行验签授权（需要理解合约验签的实现
2.Bank合约需要添加permitDeposit函数，支持离线签名授权进行存款
3.NTFMarket合约需要添加permitBuy函数，支持离线签名授权进行购买
4.需要一个白名单合约，用于管理白名单地址，只有白名单用户才能提交permitBuy，否则revert

 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC20V2} from "../../W2/D3/ERC20_Plus.sol";

contract TokenV3 is ERC20,ERC20V2,EIP712 {
  mapping(address => uint256) public nonces;
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline));
    bytes32 hash = keccak256(abi.encodePacked(
      "\x19\x01",
      DOMAIN_SEPARATOR,
      hashStruct
    ));
    address signer = ecrecover(hash, v, r, s);
  }
  function approve(address spender, uint256 amount) public override returns (bool) {
    return super.approve(spender, amount);
  }

}
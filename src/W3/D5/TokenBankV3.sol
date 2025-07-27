pragma solidity ^0.8.20;

import {TokenBankV2} from "../../W2/D3/TokenBank_Plus.sol";

contract TokenBankV3 is TokenBankV2 {
  constructor(ERC20V2 _token) TokenBankV2(_token) {}
  function permitDeposit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, amount, deadline));
    bytes32 hash = keccak256(abi.encodePacked(
      "\x19\x01",
      DOMAIN_SEPARATOR,
      hashStruct
    ));
    address signer = ecrecover(hash, v, r, s);
  }
}
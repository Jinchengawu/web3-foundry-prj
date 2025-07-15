pragma solidity ^0.8.0;
import { TokenBank } from "../D2/TokenBank.sol";
import { ERC20V2 } from "./ERC20_Plus.sol";
/***
继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，
用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。
 */


contract TokenBankV2 is TokenBank {
    mapping(address => mapping(address => uint256)) public balances;
    address public owner;

    constructor() {
      owner = msg.sender;
    }

    function deposit(uint256 amount) public override {
        super.deposit(amount);
    }
    function tokensReceived() publice {

    }
}
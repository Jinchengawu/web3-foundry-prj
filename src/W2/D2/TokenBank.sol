pragma solidity ^0.8.0;
import { BaseERC20 } from "./MyERC20.sol";
/**
编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：

deposit() : 需要记录每个地址的存入数量；
withdraw（）: 用户可以提取自己的之前存入的 token。

 */
contract TokenBank {
    address public owner;
    mapping(address => uint256) public balances;
    uint256 public totalDeposit;
    BaseERC20 public token;
    
    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
      require(msg.value > 0, "Deposit amount must be greater than 0");
      balances[msg.sender] += msg.value;
      token.transfer(address(this), msg.value);
      totalDeposit += msg.value;
    }

    function withdraw(uint256 amount) public {
      require(balances[msg.sender] > amount, "No balance to withdraw");
      payable(msg.sender).transfer(amount);
      balances[msg.sender] -= amount;
      totalDeposit -= amount;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    IERC20 public token;
    
    constructor(IERC20 _token) {
        owner = msg.sender;
        token = _token;
    }

    function deposit(uint256 amount) public virtual {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        totalDeposit += amount;
    }

    function withdraw(uint256 amount) public virtual{
        require(balances[msg.sender] >= amount, "Insufficient balance to withdraw");
        balances[msg.sender] -= amount;
        totalDeposit -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
}
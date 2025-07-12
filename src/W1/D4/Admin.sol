// SPDX-License-Identifier: MIT
pragma solidity^0.8.13;

import "./IBank.sol";

contract Admin {
    address public owner;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function adminWithdraw(IBank bank) external onlyOwner {
        require(address(bank) != address(0), "Bank address cannot be zero");
        require(address(bank).balance > 0, "Bank has no balance to withdraw");
        
        // 调用bank合约的withdraw函数，将资金转移到Admin合约
        bank.withdraw(address(this), address(bank).balance);
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }

    receive() external payable {}
}

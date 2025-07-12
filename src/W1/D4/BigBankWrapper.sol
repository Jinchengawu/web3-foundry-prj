// // SPDX-License-Identifier: MIT
// pragma solidity^0.8.13;

// import "./IBank.sol";
// import "./Bigbank2.sol";

// contract BigBankWrapper is IBank {
//     BigBank public bigBank;
//     address public owner;
    
//     constructor() {
//         bigBank = new BigBank();
//         owner = msg.sender;
//     }
    
//     modifier onlyOwner() {
//         require(msg.sender == owner, "Only owner can call this function");
//         _;
//     }
    
//     // 转移管理员权限
//     function transferOwnership(address newOwner) public onlyOwner {
//         require(newOwner != address(0), "New owner cannot be zero address");
//         owner = newOwner;
//     }
    
//     // 实现IBank接口的deposit方法
//     function deposit() public payable override {
//         bigBank.deposit{value: msg.value}();
//     }
    
//     // 实现IBank接口的withdraw方法
//     function withdraw(address _toAddress, uint256 amount) public payable override onlyOwner {
//         bigBank.withdraw(_toAddress, amount);
//     }
    
//     // 获取BigBank合约地址
//     function getBigBankAddress() public view returns (address) {
//         return address(bigBank);
//     }
    
//     // 获取BigBank合约余额
//     function getBigBankBalance() public view returns (uint256) {
//         return address(bigBank).balance;
//     }
    
//     // 接收ETH并转发到BigBank
//     receive() external payable {
//         bigBank.deposit{value: msg.value}();
//     }
// } 
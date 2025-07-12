pragma solidity^0.8.13;
/**
在 该挑战 的 Bank 合约基础之上，编写 IBank 接口及BigBank 合约，
使其满足 Bank 实现 IBank， BigBank 继承自 Bank ， 同时 BigBank 有附加要求：

要求存款金额 >0.001 ether（用modifier权限控制）
BigBank 合约支持转移管理员


编写一个 Admin 合约， Admin 合约有自己的 Owner ，
同时有一个取款函数 adminWithdraw(IBank bank) , 
adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 
合约内的资金转移到 Admin 合约地址。

 */
import "../D3/Bank.sol";

contract BigBank is Bank {
    address public bigBankOwner;

    modifier onlyBigBankOwner() {
        require(msg.sender == bigBankOwner, "Only bigBank owner can call this function");
        _;
    }

    modifier checkDeposit() {
        require(msg.value > 0.001 ether, "Deposit amount must be greater than 0.001 ether");
        _;
    }        
    
    constructor() {
        bigBankOwner = msg.sender;
    }

    function deposit() public override payable checkDeposit {
        // 调用父合约的deposit函数
        super.deposit();
    }
    
    function changeOwner(address _newOwner) public override onlyBigBankOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        bigBankOwner = _newOwner;
        super.changeOwner(_newOwner);
    }

    function withdraw(address _toAddress, uint256 amount) public payable override onlyBigBankOwner {
        // 调用父合约的withdraw函数
        super.withdraw(_toAddress, amount);
    }
}

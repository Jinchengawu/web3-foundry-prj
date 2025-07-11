pragma solidity ^0.8.0;
import "../D3/Bank.sol";
interface IBank {

  function deposit(uint256 amount) payable external;
  function withdraw(address _toAddress) payable external;
  function changeOwner(address _newOwner) external;
}



contract BigBank is IBank{
    address public owner;        

  modifier checkDeposit(){
    require(msg.value > 0.0001, "Deposit amount must be greater than 0");
    _;
  }

  modifier checkWithdraw(){
    require(msg.sender == owner, "Only owner can withdraw");
    _;
  }

  modifier checkChangeOwner(){
    require(msg.sender == owner, "Only owner can changeOwner");
    _;
  }
    constructor(){
      owner = msg.sender;
    }
    function changeOwner(address _newOwner) external checkChangeOwner{
      owner = _newOwner;
    }

    function deposit(uint256 amount) payable external checkDeposit{
      payable(owner).transfer(amount);
    }

    function withdraw(address _toAddress) payable external checkWithdraw{
      Bank bank = Bank(address(this));
      bank.withdraw( _toAddress, address(this).balance);
    }
}


contract Admin {
  address public owner;
  constructor(){
    owner = msg.sender;
  }

  // 
  function adminWithdraw(IBank bank) payable public {
    bank.withdraw(owner.address);
  }

  function changeOwner(address _newOwner) external {
    require(msg.sender == owner, "Only owner can change owner");
    owner = _newOwner;
  }
}
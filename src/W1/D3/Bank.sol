pragma solidity ^0.8.0;

contract Bank {
  //  余额映射，用来存储用户跟存款
    mapping(address => uint256) public balances;
    address[3] public Top3Address 

    function deposit(uint256 amount) public {
      balances[msg.sender] = balances[msg.sender] += amount || amount;



    }

    function getTop3Address() public view returns (address[3] memory) {


      return Top3Address;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
    }

    function getBalance(address account) public view returns (uint256) {
        return balances[account];
    }


}
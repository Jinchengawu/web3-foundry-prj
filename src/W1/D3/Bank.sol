pragma solidity ^0.8.0;

contract Bank {
  //  余额映射，用来存储用户跟存款
    mapping(address => uint256) private balances;
    address[3] private Top3Address;
    address private owner;
    address private contractAddress;

    constructor() {
      owner = msg.sender;
      contractAddress = address(this);
    }

    // 提现
    function withdraw(address _fromAddress, address _toAddress, uint256 amount) public payable{
      require(msg.sender == owner, "Only owner can withdraw");
      require(_toAddress != address(0), "toAddress is not 0");
      require(_fromAddress != address(0), "_fromAddress is not 0");
      require(contractAddress.balance >= amount, "Insufficient balance");
      balances[_fromAddress] -= amount;
      payable(_toAddress).transfer(amount);
      getTop3Address();
    }

    // 存款
    function deposit() public payable{
      require(msg.value >0 , "deposit value mast > 0" );     
      balances[msg.sender] = balances[msg.sender] += msg.value;
      if(balances[msg.sender] > balances[Top3Address[0]]){
        Top3Address[0] = msg.sender;
      }
      if(balances[msg.sender] > balances[Top3Address[1]]){
        Top3Address[1] = msg.sender;
      }
    }
    receive() external payable{
      deposit(msg.value);
    }
    // 获取前3名存款地址
    function getTop3Address() public view returns (address[3] memory) {


      return Top3Address;
    }

    // 获取合约余额
    function getBalance() public view returns (uint256) {
        return contractAddress.balance;
    }

    // 获取onwer
    function getOwner() public view returns (address) {
        return owner;
    }

    // 获取msg
    function getMsgAddress() public view returns (address) {
        return msg.sender;
    }

    function changeOwner() public {
      require(msg.sender == owner, "Only owner can change owner");
      owner = msg.sender;
    }
}
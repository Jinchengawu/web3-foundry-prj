pragma solidity^0.8.13;

interface IBank {
    function deposit() external payable;
    function withdraw(address _toAddress, uint256 amount) external payable;
    function changeOwner(address _newOwner) external;
}

contract Bank is IBank {
  //  余额映射，用来存储用户跟存款
    mapping(address => uint256) public balances;
    address[3] public Top3Address;
    address public owner;
    address public contractAddress;

    constructor() {
      owner = msg.sender;
      contractAddress = address(this);
    }

    // 提现
    function withdraw( address _toAddress, uint256 amount) public payable virtual {
      require(msg.sender == owner, "Only owner can withdraw");
      require(_toAddress != address(0), "toAddress is not 0");
      require(contractAddress.balance >= amount, "Insufficient balance");
      payable(_toAddress).transfer(amount);      
    }

    // 存款
    function deposit() public payable virtual {
      require(msg.value >0 , "deposit value mast > 0" );     
      balances[msg.sender] = balances[msg.sender] += msg.value;
      if(balances[msg.sender] > balances[Top3Address[0]]){
        Top3Address[2] = Top3Address[1];
        Top3Address[1] = Top3Address[0];
        Top3Address[0] = msg.sender;
      } else if(balances[msg.sender] > balances[Top3Address[1]]){
        Top3Address[2] = Top3Address[1];
        Top3Address[1] = msg.sender;
      } else if(balances[msg.sender] > balances[Top3Address[2]]){
        Top3Address[2] = msg.sender;
      }
    }

    // 转移管理员权限
    function changeOwner(address _newOwner) public virtual {
        require(msg.sender == owner, "Only owner can change owner");
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }

    receive() external payable{
      deposit();
    }  
}
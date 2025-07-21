pragma solidity ^0.8.0;
/***
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，
在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20V2 {
    function tokensReceived(address from, uint256 amount) external;
}

contract ERC20V2 is ERC20 {
  
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
  
  function transferWithCallback(address to, uint256 amount, bytes memory data) public returns (bool) {
    require(super.transfer(to, amount), "Transfer failed");
    if (isContract(to)) {
      IERC20V2(to).tokensReceived(msg.sender, amount, data);
    }
    return true;
  }

  function isContract(address account) internal view returns (bool) {    
    return account.code.length > 0;
  }

}
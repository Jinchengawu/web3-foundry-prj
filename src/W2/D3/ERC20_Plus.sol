pragma solidity ^0.8.0;
/***
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，
在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

 */
import "ERC20.sol";

contract ERC20V2 is ERC20 {
  
  function transferWithCallback(address to, uint256 amount) public returns (bool) {
    require(isContract(to),"ERC20V2: to is not a contract");
    super.transfer(to, amount);
    if (isContract(to)) {
      IERC20V2(to).tokensReceived(msg.sender, amount);
    }
    return true;
  }

  function isContract(address account) internal view returns (bool) {    
    return extcodesize(account) > 0;
  }

}
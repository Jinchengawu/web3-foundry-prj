

/**
编写 StakingPool 合约，实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚钱 KK Token。
其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。

（加分项）用户质押 ETH 的可存入的一个借贷市场赚取利息.

参考思路：找到 借贷市场 进行一笔存款，然后查看调用的方法，在 Stake 中集成该方法

下面是合约接口信息
*/

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title KK Token 
 */
 interface IToken {
  function transfer(address to, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function mint(address to, uint256 amount) external;
}

/**
* @title Staking Interface
*/
interface IStaking {
  /**
   * @dev 质押 ETH 到合约
   */
  function stake()  payable external;

  /**
   * @dev 赎回质押的 ETH
   * @param amount 赎回数量
   */
  function unstake(uint256 amount) external; 

  /**
   * @dev 领取 KK Token 收益
   */
  function claim() external;

  /**
   * @dev 获取质押的 ETH 数量
   * @param account 质押账户
   * @return 质押的 ETH 数量
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev 获取待领取的 KK Token 收益
   * @param account 质押账户
   * @return 待领取的 KK Token 收益
   */
  function earned(address account) external view returns (uint256);
}
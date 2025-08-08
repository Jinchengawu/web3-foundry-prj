// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// /**
// 编写一个 Vesting 合约（可参考 OpenZepplin Vesting 相关合约）， 相关的参数有：

// 1.beneficiary： 受益人
// 2.锁定的 ERC20 地址
// 3.Cliff：12 个月
// 4.线性释放：接下来的 24 个月，从 第 13 个月起开始每月解锁 1/24 的 ERC20
// 5.Vesting 合约包含的方法 release() 用来释放当前解锁的 ERC20 给受益人，
// 6.Vesting 合约部署后，开始计算 Cliff ，并转入 100 万 ERC20 资产。


// 解题：
// 1.beneficiary：项目方/空投
// 2.erc20代币
// 3.Cliff悬崖期:根据合约部署区块的时间戳 与 当前时间戳对比 如果为 达到了12个月 就会开启 cliff
// 4.countToken:根据 线形释放算法 去给每个人每个月更新可领取的余额 去结算
// 5.
// */


// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// contract Vesting  {
//   mapping(address => uint256) public beneficiarys;
//   ERC20 public immutable token; //目标erc20
//   uint256 public immutable cliffTimestamp;
//   bool public cliffLock = true;

//   function constructor(ERC20 _token){
//     token = _token;
//     cliffTimestamp = block.timestamp;
//   }

//   function 

//   function release public(){
//     uint256 blance = beneficiarys[meg.sender]
//     require(blance <= 0,'sender blance is none');
//     blance
//   }
// }

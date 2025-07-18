// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
将下方合约部署到 https://sepolia.etherscan.io/ ，要求如下：

要求使用你在 Decert.met 登录的钱包来部署合约
要求贴出编写 forge script 的脚本合约
并给出部署后的合约链接地址


 */



contract MyToken2  { 

    uint256 public totalSupply = 0;
    constructor()  {
    } 
    function main() public {
totalSupply += 1;
    }
}
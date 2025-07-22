/**
编写 NFTMarket 合约：

支持设定任意ERC20价格来上架NFT
支持支付ERC20购买指定的NFT
要求测试内容：

上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓

 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NFTMarket} from "../src/W2/D3/NFTMarket.sol";

contract NFTMarketTest is Test {
  NFTMarket public nftMarket;
  ERC20 public token;
  ERC721 public nft;

  function setUp() public {
    nftMarket = new NFTMarket(address(this));
    token = new ERC20("Token", "TKN");
    nft = new ERC721("NFT", "NFT");

    token.mint(address(this), 1000);
    nft.mint(address(this), 1);

    nftMarket.setToken(address(token));
    nftMarket.setNFT(address(nft));
  }
  
  function test_setToken() public {
    vm.expectRevert(abi.encodeWithSelector(NFTMarket.NFTMarket__TokenAlreadySet.selector));
    nftMarket.setToken(address(token));

    nftMarket.setToken(address(token));

    assertEq(nftMarket.token(), address(token));

    vm.expectRevert(abi.encodeWithSelector(NFTMarket.NFTMarket__TokenAlreadySet.selector));
  }
}
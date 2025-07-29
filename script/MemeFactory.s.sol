// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/W4/D2/MemeFactory.sol";

contract MemeFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 MemeFactory 合约
        MemeFactory factory = new MemeFactory();
        console.log("MemeFactory deployed at:", address(factory));

        // 部署一个示例 Meme 代币
        string memory symbol = "DOGE";
        uint256 totalSupply = 1000000;
        uint256 perMint = 1000;
        uint256 price = 0.001 ether;

        address memeToken = factory.deployMeme(symbol, totalSupply, perMint, price);
        console.log("Meme token deployed at:", memeToken);
        console.log("Symbol:", symbol);
        console.log("Total supply:", totalSupply);
        console.log("Per mint:", perMint);
        console.log("Price per token:", price);

        // 获取铸造费用
        uint256 mintCost = factory.getMintCost(memeToken);
        console.log("Mint cost for one batch:", mintCost);

        vm.stopBroadcast();
    }
} 
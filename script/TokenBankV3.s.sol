// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenBankV3} from "../src/W3/D5/TokenBankV3.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";

contract TokenBankV3Script is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 TokenV3
        TokenV3 token = new TokenV3("MyToken", "MTK");
        console.log("TokenV3 deployed at:", address(token));

        // 部署 TokenBankV3
        TokenBankV3 tokenBank = new TokenBankV3(token);
        console.log("TokenBankV3 deployed at:", address(tokenBank));

        // 给部署者一些代币用于测试
        token.mint(msg.sender, 10000e18);
        console.log("Minted 10000 tokens to deployer");

        vm.stopBroadcast();
    }
} 
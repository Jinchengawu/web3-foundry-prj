// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/W2/D4/MyToken copy.sol";

contract MyTokenScript is Script {
    MyToken public myToken;
    
    // 部署配置
    string public constant TOKEN_NAME = "MyToken-WJK";
    string public constant TOKEN_SYMBOL = "MTK-WJK";
    uint256 public constant INITIAL_SUPPLY = 1e10 * 1e18; // 100亿代币

    function setUp() public {}

    function run() public {
        // 获取部署者地址
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        // 验证私钥
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address expectedAddress = vm.addr(privateKey);
        
        require(deployer == expectedAddress, "Private key does not match deployer address");
        
        console.log("Deployer address:", deployer);
        console.log("Token name:", TOKEN_NAME);
        console.log("Token symbol:", TOKEN_SYMBOL);
        console.log("Initial supply:", INITIAL_SUPPLY);
        
        vm.startBroadcast(privateKey);

        // 部署代币合约
        myToken = new MyToken(TOKEN_NAME, TOKEN_SYMBOL);
        
        console.log("Token contract deployed to:", address(myToken));
        console.log("Deployer balance:", myToken.balanceOf(deployer));

        vm.stopBroadcast();
        
        // 验证部署结果
        require(keccak256(bytes(myToken.name())) == keccak256(bytes(TOKEN_NAME)), "Token name mismatch");
        require(keccak256(bytes(myToken.symbol())) == keccak256(bytes(TOKEN_SYMBOL)), "Token symbol mismatch");
        require(myToken.balanceOf(deployer) == INITIAL_SUPPLY, "Initial supply mismatch");
        
        console.log("Deployment verification successful!");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Oracle.sol";

contract DeployOracle is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 Oracle 合约
        Oracle oracle = new Oracle();
        
        console.log("Oracle contract deployed to:", address(oracle));
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        
        // 可选：添加额外的授权更新者
        // oracle.addAuthorizedUpdater(0x...);
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== Oracle Deployment Complete ===");
        console.log("Contract address:", address(oracle));
        console.log("Owner:", oracle.owner());
        console.log("Default TWAP window:", oracle.DEFAULT_TWAP_WINDOW(), "seconds");
        console.log("Max price change:", oracle.MAX_PRICE_CHANGE(), "%");
        console.log("Contract status:", oracle.paused() ? "Paused" : "Running");
    }
} 
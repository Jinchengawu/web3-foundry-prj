// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/W6/D1/rebaseToken/RebaseToken.sol";

/**
 * @title DeployRebaseToken
 * @dev RebaseToken部署脚本
 * @author dreamworks.cnn@gmail.com
 */
contract DeployRebaseToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署RebaseToken合约
        RebaseToken rebaseToken = new RebaseToken(
            "Rebase Token",  // 名称
            "RBT"           // 符号
        );

        vm.stopBroadcast();

        // 输出部署信息
        console.log("=== RebaseToken Deployment Success ===");
        console.log("Contract Address:", address(rebaseToken));
        console.log("Token Name:", rebaseToken.name());
        console.log("Token Symbol:", rebaseToken.symbol());
        console.log("Initial Total Supply:", rebaseToken.totalSupply());
        console.log("Initial Rebase Index:", rebaseToken.getRebaseIndex());
        console.log("Annual Deflation Rate:", rebaseToken.getAnnualDeflation());
        console.log("Deployer Address:", vm.addr(deployerPrivateKey));
        console.log("=====================================");
    }
} 
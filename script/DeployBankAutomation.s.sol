// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/W5/D3/TokenBankV4.sol";
import "../src/W5/D3/Automation-compatible-contract.sol";
import "../src/W3/D5/TokenV3.sol";

/**
 * @title DeployBankAutomation
 * @dev 部署 TokenBankV4 和 BankAutomation 合约的脚本
 */
contract DeployBankAutomation is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署参数
        uint256 autoTransferThreshold = 1000 * 10**18; // 1000 个代币作为阈值
        uint256 checkInterval = 300; // 5分钟检查一次
        uint256 minTransferInterval = 3600; // 最小转移间隔1小时
        
        // 1. 部署或使用现有的 TokenV3
        TokenV3 token;
        address existingTokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        
        if (existingTokenAddress != address(0)) {
            token = TokenV3(existingTokenAddress);
            console.log("Using existing TokenV3 at:", existingTokenAddress);
        } else {
            // 部署新的 TokenV3
            token = new TokenV3("BankToken", "BT");
            console.log("Deployed new TokenV3 at:", address(token));
        }
        
        // 2. 部署 TokenBankV4
        TokenBankV4 bankV4 = new TokenBankV4(token, autoTransferThreshold);
        console.log("Deployed TokenBankV4 at:", address(bankV4));
        console.log("Auto transfer threshold:", autoTransferThreshold);
        
        // 3. 部署 BankAutomation
        BankAutomation automation = new BankAutomation(
            address(bankV4),
            checkInterval,
            minTransferInterval
        );
        console.log("Deployed BankAutomation at:", address(automation));
        console.log("Check interval:", checkInterval, "seconds");
        console.log("Min transfer interval:", minTransferInterval, "seconds");
        
        // 4. 设置 TokenBankV4 的自动化合约地址
        bankV4.setAutomationContract(address(automation));
        console.log("Set automation contract address in TokenBankV4");
        
        // 5. 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("TokenV3:", address(token));
        console.log("TokenBankV4:", address(bankV4));
        console.log("BankAutomation:", address(automation));
        console.log("Bank Owner:", bankV4.owner());
        console.log("Automation Owner:", automation.owner());
        
        // 6. 验证配置
        console.log("\n=== Configuration Verification ===");
        console.log("Auto transfer enabled:", bankV4.autoTransferEnabled());
        console.log("Auto transfer threshold:", bankV4.autoTransferThreshold());
        console.log("Automation contract:", bankV4.automationContract());
        
        vm.stopBroadcast();
        
        // 7. 输出使用说明
        console.log("\n=== Usage Instructions ===");
        console.log("1. Users need to approve TokenBankV4 contract to use tokens");
        console.log("2. Users call deposit() method to deposit");
        console.log("3. When total deposit exceeds threshold, Chainlink Automation will auto transfer half to owner");
        console.log("4. Register BankAutomation contract address in Chainlink Automation");
    }
}
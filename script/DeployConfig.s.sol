// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/W2/D4/MyToken.sol";

contract DeployConfig is Script {
    // 网络配置
    struct NetworkConfig {
        string name;
        uint256 chainId;
        string rpcUrl;
        string etherscanApiKey;
        bool verify;
    }
    
    // 部署配置
    struct DeployParams {
        string tokenName;
        string tokenSymbol;
        uint256 initialSupply;
        address deployer;
        uint256 privateKey;
    }
    
    NetworkConfig public networkConfig;
    DeployParams public deployParams;
    MyToken public deployedToken;
    
    function setUp() public {
        // 根据链ID设置网络配置
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) { // Sepolia
            networkConfig = NetworkConfig({
                name: "Sepolia",
                chainId: 11155111,
                rpcUrl: vm.envString("SEPOLIA_RPC_URL"),
                etherscanApiKey: vm.envString("ETHERSCAN_API_KEY"),
                verify: true
            });
        } else if (chainId == 1) { // Mainnet
            networkConfig = NetworkConfig({
                name: "Mainnet",
                chainId: 1,
                rpcUrl: vm.envString("MAINNET_RPC_URL"),
                etherscanApiKey: vm.envString("ETHERSCAN_API_KEY"),
                verify: true
            });
        } else if (chainId == 31337) { // Anvil
            networkConfig = NetworkConfig({
                name: "Anvil",
                chainId: 31337,
                rpcUrl: "http://localhost:8545",
                etherscanApiKey: "",
                verify: false
            });
        } else {
            revert("Unsupported network");
        }
        
        // 设置部署配置
        deployParams = DeployParams({
            tokenName: vm.envString("TOKEN_NAME"),
            tokenSymbol: vm.envString("TOKEN_SYMBOL"),
            initialSupply: vm.envUint("INITIAL_SUPPLY"),
            deployer: vm.envAddress("DEPLOYER_ADDRESS"),
            privateKey: vm.envUint("PRIVATE_KEY")
        });
        
        // 验证私钥与地址匹配
        require(deployParams.deployer == vm.addr(deployParams.privateKey), 
                "Private key does not match deployer address");
    }
    
    function run() public {
        console.log("Network:", networkConfig.name);
        console.log("Chain ID:", networkConfig.chainId);
        console.log("Deployer:", deployParams.deployer);
        console.log("Token name:", deployParams.tokenName);
        console.log("Token symbol:", deployParams.tokenSymbol);
        console.log("Initial supply:", deployParams.initialSupply);
        
        vm.startBroadcast(deployParams.privateKey);
        
        // 部署代币合约
        deployedToken = new MyToken(deployParams.tokenName, deployParams.tokenSymbol);
        
        console.log("Contract deployed to:", address(deployedToken));
        console.log("Deployer balance:", deployedToken.balanceOf(deployParams.deployer));
        
        vm.stopBroadcast();
        
        // 验证部署
        _verifyDeployment();
        
        // 输出部署信息
        _printDeploymentInfo();
    }
    
    function _verifyDeployment() internal view {
        require(keccak256(bytes(deployedToken.name())) == keccak256(bytes(deployParams.tokenName)), "Token name mismatch");
        require(keccak256(bytes(deployedToken.symbol())) == keccak256(bytes(deployParams.tokenSymbol)), "Token symbol mismatch");
        require(deployedToken.balanceOf(deployParams.deployer) == deployParams.initialSupply, 
                "Initial supply mismatch");
        console.log("Deployment verification successful");
    }
    
    function _printDeploymentInfo() internal view {
        console.log("\nDeployment Info:");
        console.log("Contract address:", address(deployedToken));
        console.log("Network:", networkConfig.name);
        console.log("Chain ID:", networkConfig.chainId);
        console.log("Deployer:", deployParams.deployer);
        console.log("Token name:", deployedToken.name());
        console.log("Token symbol:", deployedToken.symbol());
        console.log("Total supply:", deployedToken.totalSupply());
        console.log("Deployer balance:", deployedToken.balanceOf(deployParams.deployer));
        
        if (networkConfig.verify) {
            console.log("\nContract Verification:");
            console.log("Etherscan API Key:", networkConfig.etherscanApiKey);
            console.log("Verification status: Enabled");
        }
    }
} 
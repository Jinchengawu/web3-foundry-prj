#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// 颜色输出
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// 网络配置
const NETWORKS = {
    sepolia: {
        name: 'Sepolia',
        chainId: 11155111,
        rpcUrl: process.env.SEPOLIA_RPC_URL,
        etherscanApiKey: process.env.ETHERSCAN_API_KEY,
        verify: true
    },
    mainnet: {
        name: 'Mainnet',
        chainId: 1,
        rpcUrl: process.env.MAINNET_RPC_URL,
        etherscanApiKey: process.env.ETHERSCAN_API_KEY,
        verify: true
    },
    anvil: {
        name: 'Anvil',
        chainId: 31337,
        rpcUrl: 'http://localhost:8545',
        etherscanApiKey: '',
        verify: false
    }
};

// 默认配置
const DEFAULT_CONFIG = {
    tokenName: 'MyToken-WJK',
    tokenSymbol: 'MTK-WJK',
    initialSupply: '10000000000000000000000000000', // 100亿代币
    deployerAddress: process.env.DEPLOYER_ADDRESS,
    privateKey: process.env.PRIVATE_KEY
};

function checkEnvironment() {
    log('🔍 检查环境配置...', 'cyan');
    
    const requiredVars = ['DEPLOYER_ADDRESS', 'PRIVATE_KEY'];
    const missing = requiredVars.filter(varName => !process.env[varName]);
    
    if (missing.length > 0) {
        log(`❌ 缺少必要的环境变量: ${missing.join(', ')}`, 'red');
        log('请创建 .env 文件并设置以下变量:', 'yellow');
        log('DEPLOYER_ADDRESS=你的钱包地址', 'yellow');
        log('PRIVATE_KEY=你的私钥(不含0x前缀)', 'yellow');
        log('SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID', 'yellow');
        log('ETHERSCAN_API_KEY=你的Etherscan API密钥', 'yellow');
        process.exit(1);
    }
    
    log('✅ 环境配置检查通过', 'green');
}

function loadEnvFile() {
    const envPath = path.join(process.cwd(), '.env');
    if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        envContent.split('\n').forEach(line => {
            const [key, value] = line.split('=');
            if (key && value && !process.env[key]) {
                process.env[key] = value.trim();
            }
        });
        log('📄 已加载 .env 文件', 'green');
    }
}

function validateNetwork(network) {
    if (!NETWORKS[network]) {
        log(`❌ 不支持的网络: ${network}`, 'red');
        log(`支持的网络: ${Object.keys(NETWORKS).join(', ')}`, 'yellow');
        process.exit(1);
    }
    
    const networkConfig = NETWORKS[network];
    if (networkConfig.verify && !networkConfig.etherscanApiKey) {
        log(`⚠️  警告: 网络 ${network} 需要 ETHERSCAN_API_KEY 进行合约验证`, 'yellow');
    }
    
    if (!networkConfig.rpcUrl) {
        log(`❌ 错误: 网络 ${network} 缺少 RPC URL`, 'red');
        process.exit(1);
    }
    
    return networkConfig;
}

function buildContracts() {
    log('🔨 编译合约...', 'cyan');
    try {
        execSync('forge build', { stdio: 'inherit' });
        log('✅ 合约编译成功', 'green');
    } catch (error) {
        log('❌ 合约编译失败', 'red');
        process.exit(1);
    }
}

function deployContract(network, scriptName = 'foundry.s.sol:MyTokenScript') {
    const networkConfig = validateNetwork(network);
    
    log(`🚀 开始部署到 ${networkConfig.name}...`, 'cyan');
    log(`📋 部署配置:`, 'blue');
    log(`  网络: ${networkConfig.name}`, 'blue');
    log(`  链ID: ${networkConfig.chainId}`, 'blue');
    log(`  部署者: ${DEFAULT_CONFIG.deployerAddress}`, 'blue');
    log(`  代币名称: ${DEFAULT_CONFIG.tokenName}`, 'blue');
    log(`  代币符号: ${DEFAULT_CONFIG.tokenSymbol}`, 'blue');
    
    const command = [
        'forge script',
        `script/${scriptName}`,
        `--rpc-url "${networkConfig.rpcUrl}"`,
        `--private-key "${DEFAULT_CONFIG.privateKey}"`,
        '--broadcast',
        '-vvvv'
    ];
    
    if (networkConfig.verify && networkConfig.etherscanApiKey) {
        command.push(`--verify`);
        command.push(`--etherscan-api-key "${networkConfig.etherscanApiKey}"`);
    }
    
    try {
        execSync(command.join(' '), { stdio: 'inherit' });
        log('✅ 部署成功!', 'green');
    } catch (error) {
        log('❌ 部署失败', 'red');
        process.exit(1);
    }
}

function main() {
    const args = process.argv.slice(2);
    const network = args[0] || 'sepolia';
    
    log('🎯 MyToken 部署工具', 'bright');
    log('==================', 'bright');
    
    // 加载环境变量
    loadEnvFile();
    
    // 检查环境
    checkEnvironment();
    
    // 编译合约
    buildContracts();
    
    // 部署合约
    deployContract(network);
    
    log('\n🎉 部署完成!', 'green');
    log('请检查上面的输出获取合约地址', 'cyan');
}

if (require.main === module) {
    main();
}

module.exports = {
    NETWORKS,
    DEFAULT_CONFIG,
    deployContract,
    validateNetwork
}; 
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
function getNetworks() {
    return {
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
}

// 默认配置
function getDefaultConfig() {
    return {
        tokenName: 'MyToken-WJK',
        tokenSymbol: 'MTK-WJK',
        initialSupply: '10000000000000000000000000000', // 100亿代币
        deployerAddress: process.env.DEPLOYER_ADDRESS,
        privateKey: process.env.PRIVATE_KEY
    };
}

function checkEnvironment() {
    log('🔍 检查环境配置...', 'cyan');
    
    const requiredVars = ['DEPLOYER_ADDRESS', 'PRIVATE_KEY'];
    const missing = requiredVars.filter(varName => {
        const value = process.env[varName];
        return !value || value === '你的钱包地址' || value === '你的私钥(不含0x前缀)';
    });
    
    if (missing.length > 0) {
        log(`❌ 缺少必要的环境变量: ${missing.join(', ')}`, 'red');
        log('请创建 .env 文件并设置以下变量:', 'yellow');
        log('DEPLOYER_ADDRESS=你的钱包地址', 'yellow');
        log('PRIVATE_KEY=你的私钥(不含0x前缀)', 'yellow');
        log('SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID', 'yellow');
        log('ETHERSCAN_API_KEY=你的Etherscan API密钥', 'yellow');
        log('\n📝 创建 .env 文件的步骤:', 'cyan');
        log('1. 复制 .env.example 文件为 .env: cp .env.example .env', 'cyan');
        log('2. 编辑 .env 文件并填入你的实际值', 'cyan');
        log('3. 保存文件后重新运行部署脚本', 'cyan');
        log('\n💡 提示: 你可以从以下地方获取这些值:', 'cyan');
        log('- 钱包地址和私钥: 从你的钱包导出', 'cyan');
        log('- RPC URL: Infura, Alchemy, QuickNode 等提供商', 'cyan');
        log('- Etherscan API Key: https://etherscan.io/apis', 'cyan');
        log('\n⚠️  注意: 当前 .env 文件中的值是示例，需要替换为真实值', 'yellow');
        log('\n📖 详细配置说明请参考: ENVIRONMENT_SETUP.md', 'cyan');
        process.exit(1);
    }
    
    // 检查网络配置
    const networkVars = ['SEPOLIA_RPC_URL', 'MAINNET_RPC_URL'];
    const networkIssues = networkVars.filter(varName => {
        const value = process.env[varName];
        return value && (value.includes('YOUR_PROJECT_ID') || value.includes('YOUR_API_KEY'));
    });
    
    if (networkIssues.length > 0) {
        log(`⚠️  警告: 以下网络配置仍使用示例值: ${networkIssues.join(', ')}`, 'yellow');
        log('请更新为真实的 RPC URL', 'yellow');
        log('参考 QUICK_FIX.md 获取详细修复步骤', 'cyan');
        
        // 如果 SEPOLIA_RPC_URL 有问题，阻止部署
        if (networkIssues.includes('SEPOLIA_RPC_URL')) {
            log('❌ 无法部署：SEPOLIA_RPC_URL 配置错误', 'red');
            log('请先修复 RPC URL 配置', 'red');
            process.exit(1);
        }
    }
    
    // 检查 Etherscan API Key
    if (process.env.ETHERSCAN_API_KEY && process.env.ETHERSCAN_API_KEY === '你的Etherscan API密钥') {
        log('⚠️  警告: ETHERSCAN_API_KEY 仍使用示例值', 'yellow');
        log('合约将部署但不会在 Etherscan 上验证', 'yellow');
    }
    
    log('✅ 环境配置检查通过', 'green');
}

function loadEnvFile() {
    const envPath = path.join(process.cwd(), '.env');
    if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        let loadedCount = 0;
        envContent.split('\n').forEach(line => {
            // 跳过注释行和空行
            if (line.trim() && !line.trim().startsWith('#')) {
                const equalIndex = line.indexOf('=');
                if (equalIndex > 0) {
                    const key = line.substring(0, equalIndex).trim();
                    const value = line.substring(equalIndex + 1).trim();
                            if (key && value && !process.env[key]) {
            process.env[key] = value;
            loadedCount++;
        }
                }
            }
        });
        log(`📄 已加载 .env 文件 (${loadedCount} 个变量)`, 'green');
    } else {
        log('⚠️  未找到 .env 文件', 'yellow');
        log('请创建 .env 文件并设置必要的环境变量', 'yellow');
    }
}

function validateNetwork(network) {
    const networks = getNetworks();
    if (!networks[network]) {
        log(`❌ 不支持的网络: ${network}`, 'red');
        log(`支持的网络: ${Object.keys(networks).join(', ')}`, 'yellow');
        process.exit(1);
    }
    
    const networkConfig = networks[network];
    
    if (!networkConfig.rpcUrl) {
        log(`❌ 错误: 网络 ${network} 缺少 RPC URL`, 'red');
        log(`请检查环境变量 ${network.toUpperCase()}_RPC_URL 是否正确设置`, 'yellow');
        log('例如: SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID', 'yellow');
        process.exit(1);
    }
    
    if (networkConfig.verify && !networkConfig.etherscanApiKey) {
        log(`⚠️  警告: 网络 ${network} 需要 ETHERSCAN_API_KEY 进行合约验证`, 'yellow');
        log('合约将部署但不会在 Etherscan 上验证', 'yellow');
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

// foundry.s.sol:MyTokenScript
function deployContract(network, scriptName = '') {
    const networkConfig = validateNetwork(network);
    const config = getDefaultConfig();
    
    log(`🚀 开始部署到 ${networkConfig.name}...`, 'cyan');
    log(`📋 部署配置:`, 'blue');
    log(`  网络: ${networkConfig.name}`, 'blue');
    log(`  链ID: ${networkConfig.chainId}`, 'blue');
    log(`  部署者: ${config.deployerAddress}`, 'blue');
    log(`  代币名称: ${config.tokenName}`, 'blue');
    log(`  代币符号: ${config.tokenSymbol}`, 'blue');
    
    const command = [
        'forge script',
        `script/${scriptName}`,
        `--rpc-url "${networkConfig.rpcUrl}"`,
        `--private-key "${config.privateKey}"`,
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
    const scriptName = args[1] || '';
    
    log('🎯 MyToken 部署工具', 'bright');
    log('==================', 'bright');
    
    // 显示使用说明
    if (args.length === 0) {
        log('📖 使用方法:', 'cyan');
        log('  node scripts/deploy.js [network] [scriptName]', 'cyan');
        log('  示例:', 'cyan');
        log('    node scripts/deploy.js sepolia ERC20_Plus.s.sol', 'cyan');
        log('    node scripts/deploy.js mainnet TokenBank.s.sol', 'cyan');
        log('    node scripts/deploy.js anvil SafeBank.s.sol', 'cyan');
        log('');
    }
    
    // 检查脚本名称
    if (!scriptName) {
        log('❌ 错误: 缺少脚本名称参数', 'red');
        log('请指定要部署的脚本文件，例如:', 'yellow');
        log('  node scripts/deploy.js sepolia ERC20_Plus.s.sol', 'yellow');
        log('  node scripts/deploy.js sepolia TokenBank.s.sol', 'yellow');
        log('  node scripts/deploy.js sepolia SafeBank.s.sol', 'yellow');
        process.exit(1);
    }
    
    // 检查脚本文件是否存在
    const scriptPath = path.join(process.cwd(), 'script', scriptName);
    if (!fs.existsSync(scriptPath)) {
        log(`❌ 错误: 脚本文件不存在: script/${scriptName}`, 'red');
        log('请检查脚本文件名是否正确', 'yellow');
        log('可用的脚本文件:', 'yellow');
        try {
            const scriptFiles = fs.readdirSync('script').filter(file => file.endsWith('.s.sol'));
            scriptFiles.forEach(file => log(`  - ${file}`, 'cyan'));
        } catch (error) {
            log('  无法读取 script 目录', 'red');
        }
        process.exit(1);
    }
    
    // 加载环境变量
    loadEnvFile();
    
    // 检查环境
    checkEnvironment();
    
    // 编译合约
    buildContracts();
    
    // 部署合约
    deployContract(network, scriptName);
    
    log('\n🎉 部署完成!', 'green');
    log('请检查上面的输出获取合约地址', 'cyan');
}

if (require.main === module) {
    main();
}

module.exports = {
    getNetworks,
    getDefaultConfig,
    deployContract,
    validateNetwork
}; 
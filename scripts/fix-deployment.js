#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

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

function createInterface() {
    return readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
}

function fixEtherscanApiKey() {
    log('🔧 修复 Etherscan API 密钥问题', 'bright');
    log('================================', 'bright');
    
    const rl = createInterface();
    
    log('\n📋 问题诊断:', 'cyan');
    log('❌ 错误: "Too many invalid api key attempts"', 'red');
    log('原因: ETHERSCAN_API_KEY 设置为示例值或无效', 'yellow');
    
    log('\n🛠️  解决方案:', 'cyan');
    log('1. 获取有效的 Etherscan API 密钥', 'blue');
    log('2. 临时禁用合约验证', 'blue');
    log('3. 使用其他验证服务', 'blue');
    
    rl.question('\n请选择解决方案 (1-3): ', (answer) => {
        switch(answer.trim()) {
            case '1':
                getEtherscanApiKey(rl);
                break;
            case '2':
                disableVerification(rl);
                break;
            case '3':
                useAlternativeVerification(rl);
                break;
            default:
                log('❌ 无效选择', 'red');
                rl.close();
        }
    });
}

function getEtherscanApiKey(rl) {
    log('\n🔑 获取 Etherscan API 密钥步骤:', 'cyan');
    log('1. 访问 https://etherscan.io/apis', 'blue');
    log('2. 注册/登录账户', 'blue');
    log('3. 点击 "Add" 创建新的 API 密钥', 'blue');
    log('4. 复制生成的 API 密钥', 'blue');
    
    rl.question('\n请输入你的 Etherscan API 密钥: ', (apiKey) => {
        if (apiKey.trim()) {
            updateEnvFile('ETHERSCAN_API_KEY', apiKey.trim());
            log('✅ API 密钥已更新', 'green');
            log('现在可以重新运行部署脚本', 'cyan');
        } else {
            log('❌ API 密钥不能为空', 'red');
        }
        rl.close();
    });
}

function disableVerification(rl) {
    log('\n⚠️  临时禁用合约验证', 'yellow');
    log('这将允许合约部署，但不会在 Etherscan 上验证', 'yellow');
    
    rl.question('确认禁用验证? (y/N): ', (answer) => {
        if (answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes') {
            // 修改部署脚本以跳过验证
            const deployScriptPath = path.join(process.cwd(), 'scripts', 'deploy.js');
            let content = fs.readFileSync(deployScriptPath, 'utf8');
            
            // 替换验证逻辑
            const newContent = content.replace(
                /if \(networkConfig\.verify && networkConfig\.etherscanApiKey\) \{[\s\S]*?command\.push\(`--etherscan-api-key "\${networkConfig\.etherscanApiKey}"`\);\s*\}/,
                `// 临时禁用验证
    if (false && networkConfig.verify && networkConfig.etherscanApiKey) {
        command.push(\`--verify\`);
        command.push(\`--etherscan-api-key "\${networkConfig.etherscanApiKey}"\`);
    } else {
        log('⚠️  跳过合约验证 (已临时禁用)', 'yellow');
    }`
            );
            
            fs.writeFileSync(deployScriptPath, newContent);
            log('✅ 已临时禁用合约验证', 'green');
            log('现在可以重新运行部署脚本', 'cyan');
        } else {
            log('❌ 操作已取消', 'red');
        }
        rl.close();
    });
}

function useAlternativeVerification(rl) {
    log('\n🔄 使用其他验证服务', 'cyan');
    log('1. Sourcify (免费，无需API密钥)', 'blue');
    log('2. Blockscout (某些网络支持)', 'blue');
    log('3. 手动验证', 'blue');
    
    rl.question('请选择验证服务 (1-3): ', (answer) => {
        switch(answer.trim()) {
            case '1':
                setupSourcifyVerification(rl);
                break;
            case '2':
                log('⚠️  Blockscout 验证需要特定网络支持', 'yellow');
                rl.close();
                break;
            case '3':
                showManualVerification(rl);
                break;
            default:
                log('❌ 无效选择', 'red');
                rl.close();
        }
    });
}

function setupSourcifyVerification(rl) {
    log('\n📋 Sourcify 验证设置:', 'cyan');
    log('Sourcify 是一个免费的合约验证服务', 'blue');
    log('无需 API 密钥，但需要手动上传合约源码', 'blue');
    
    log('\n🔧 修改部署脚本以使用 Sourcify:', 'cyan');
    const deployScriptPath = path.join(process.cwd(), 'scripts', 'deploy.js');
    let content = fs.readFileSync(deployScriptPath, 'utf8');
    
    // 添加 Sourcify 验证选项
    const sourcifyOption = `
    // 使用 Sourcify 验证 (可选)
    if (networkConfig.verify) {
        command.push(\`--verify\`);
        command.push(\`--verifier sourcify\`);
    }`;
    
    // 在验证逻辑后添加 Sourcify 选项
    const newContent = content.replace(
        /if \(networkConfig\.verify && networkConfig\.etherscanApiKey && networkConfig\.etherscanApiKey !== '你的Etherscan API密钥'\) \{[\s\S]*?log\('⚠️  跳过合约验证 \(API密钥未配置或无效\)', 'yellow'\);\s*\}/,
        `if (networkConfig.verify && networkConfig.etherscanApiKey && networkConfig.etherscanApiKey !== '你的Etherscan API密钥') {
        command.push(\`--verify\`);
        command.push(\`--etherscan-api-key "\${networkConfig.etherscanApiKey}"\`);
    } else {
        log('⚠️  跳过 Etherscan 验证，使用 Sourcify', 'yellow');
        command.push(\`--verify\`);
        command.push(\`--verifier sourcify\`);
    }`
    );
    
    fs.writeFileSync(deployScriptPath, newContent);
    log('✅ 已配置 Sourcify 验证', 'green');
    log('现在可以重新运行部署脚本', 'cyan');
    rl.close();
}

function showManualVerification(rl) {
    log('\n📖 手动验证步骤:', 'cyan');
    log('1. 部署合约后，复制合约地址', 'blue');
    log('2. 访问 https://sepolia.etherscan.io/', 'blue');
    log('3. 搜索你的合约地址', 'blue');
    log('4. 点击 "Contract" 标签', 'blue');
    log('5. 点击 "Verify and Publish"', 'blue');
    log('6. 选择编译器版本和优化设置', 'blue');
    log('7. 上传合约源码', 'blue');
    log('8. 提交验证', 'blue');
    
    log('\n💡 提示: 手动验证需要确保编译器设置与部署时一致', 'yellow');
    rl.close();
}

function updateEnvFile(key, value) {
    const envPath = path.join(process.cwd(), '.env');
    let content = fs.readFileSync(envPath, 'utf8');
    
    // 替换或添加环境变量
    const regex = new RegExp(`^${key}=.*$`, 'm');
    if (regex.test(content)) {
        content = content.replace(regex, `${key}=${value}`);
    } else {
        content += `\n${key}=${value}`;
    }
    
    fs.writeFileSync(envPath, content);
    log(`✅ 已更新 ${key}`, 'green');
}

function main() {
    log('🎯 部署问题修复工具', 'bright');
    log('==================', 'bright');
    
    fixEtherscanApiKey();
}

if (require.main === module) {
    main();
}

module.exports = {
    fixEtherscanApiKey,
    updateEnvFile
}; 
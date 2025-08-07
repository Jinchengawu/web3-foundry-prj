const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// 颜色输出函数
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(colors[color] + message + colors.reset);
}

// 合约地址 (从部署日志获取)
const CONTRACTS = {
    TokenV3: '0x9CEAee8E52B76F4C296aF6293675fB9b797fd0Af',
    TokenBankV4: '0xe5c40B5F76700c3177E76c148D1A6b8569c69Bd9',
    BankAutomation: '0xBE3eb1794d87a9fCa05C603E95Bb91828C80Aec5',
    owner: '0xcC44277d1d6eC279Cd81e23111B1701758A3f82F'
};

// ABI 定义
const TOKEN_ABI = [
    "function mint(address to, uint256 amount) external",
    "function balanceOf(address account) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function name() external view returns (string)",
    "function symbol() external view returns (string)",
    "function decimals() external view returns (uint8)"
];

const BANK_ABI = [
    "function deposit(uint256 amount) external",
    "function withdraw(uint256 amount) external", 
    "function balances(address account) external view returns (uint256)",
    "function totalDeposit() external view returns (uint256)",
    "function owner() external view returns (address)",
    "function autoTransferThreshold() external view returns (uint256)",
    "function autoTransferEnabled() external view returns (bool)",
    "function automationContract() external view returns (address)",
    "function checkAutoTransfer() external view returns (bool needsTransfer, uint256 transferAmount)"
];

const AUTOMATION_ABI = [
    "function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData)",
    "function getBankStatus() external view returns (uint256 totalDeposit, uint256 threshold, bool enabled, bool needsTransfer, uint256 transferAmount)",
    "function getAutomationStatus() external view returns (uint256 lastCheck, uint256 lastTransfer, uint256 nextCheckTime, uint256 nextTransferTime)"
];

class BankDepositScript {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.tokenContract = null;
        this.bankContract = null;
        this.automationContract = null;
    }

    async initialize() {
        log('🔧 初始化连接...', 'cyan');
        
        // 设置网络提供者
        const rpcUrl = process.env.SEPOLIA_RPC_URL;
        if (!rpcUrl) {
            throw new Error('❌ SEPOLIA_RPC_URL 未在 .env 文件中设置');
        }
        
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        
        // 设置签名者
        const privateKey = process.env.PRIVATE_KEY;
        if (!privateKey) {
            throw new Error('❌ PRIVATE_KEY 未在 .env 文件中设置');
        }
        
        this.signer = new ethers.Wallet(privateKey, this.provider);
        
        // 连接合约
        this.tokenContract = new ethers.Contract(CONTRACTS.TokenV3, TOKEN_ABI, this.signer);
        this.bankContract = new ethers.Contract(CONTRACTS.TokenBankV4, BANK_ABI, this.signer);
        this.automationContract = new ethers.Contract(CONTRACTS.BankAutomation, AUTOMATION_ABI, this.provider);
        
        log('✅ 连接初始化成功', 'green');
        log(`📡 网络: Sepolia`, 'blue');
        log(`👤 用户地址: ${this.signer.address}`, 'blue');
    }

    async checkBalances() {
        log('\n📊 检查当前余额...', 'cyan');
        
        const userAddress = this.signer.address;
        
        // 获取代币信息
        const tokenName = await this.tokenContract.name();
        const tokenSymbol = await this.tokenContract.symbol();
        const decimals = await this.tokenContract.decimals();
        
        // 检查用户代币余额
        const tokenBalance = await this.tokenContract.balanceOf(userAddress);
        const tokenBalanceFormatted = ethers.formatUnits(tokenBalance, decimals);
        
        // 检查银行存款余额
        const bankBalance = await this.bankContract.balances(userAddress);
        const bankBalanceFormatted = ethers.formatUnits(bankBalance, decimals);
        
        // 检查总存款
        const totalDeposit = await this.bankContract.totalDeposit();
        const totalDepositFormatted = ethers.formatUnits(totalDeposit, decimals);
        
        // 检查授权额度
        const allowance = await this.tokenContract.allowance(userAddress, CONTRACTS.TokenBankV4);
        const allowanceFormatted = ethers.formatUnits(allowance, decimals);
        
        log(`💰 代币 (${tokenName} - ${tokenSymbol}) 余额: ${tokenBalanceFormatted}`, 'yellow');
        log(`🏦 银行存款余额: ${bankBalanceFormatted}`, 'yellow');
        log(`📈 银行总存款: ${totalDepositFormatted}`, 'yellow');
        log(`🔑 授权额度: ${allowanceFormatted}`, 'yellow');
        
        return {
            tokenBalance: tokenBalance,
            bankBalance: bankBalance,
            totalDeposit: totalDeposit,
            allowance: allowance,
            decimals: decimals
        };
    }

    async checkBankConfiguration() {
        log('\n⚙️ 检查银行配置...', 'cyan');
        
        const threshold = await this.bankContract.autoTransferThreshold();
        const enabled = await this.bankContract.autoTransferEnabled();
        const automationContract = await this.bankContract.automationContract();
        
        const thresholdFormatted = ethers.formatEther(threshold);
        
        log(`🎯 自动转移阈值: ${thresholdFormatted} tokens`, 'blue');
        log(`🔄 自动转移启用: ${enabled ? '是' : '否'}`, 'blue');
        log(`🤖 自动化合约: ${automationContract}`, 'blue');
        
        return { threshold, enabled, automationContract };
    }

    async mintTokensIfNeeded(requiredAmount, currentBalance, decimals) {
        if (currentBalance < requiredAmount) {
            const mintAmount = requiredAmount - currentBalance;
            const mintAmountFormatted = ethers.formatUnits(mintAmount, decimals);
            
            log(`\n🪙 铸造代币 ${mintAmountFormatted} tokens...`, 'cyan');
            
            try {
                const tx = await this.tokenContract.mint(this.signer.address, mintAmount);
                log(`📤 交易已发送: ${tx.hash}`, 'yellow');
                
                const receipt = await tx.wait();
                log(`✅ 代币铸造成功! Gas 使用: ${receipt.gasUsed.toString()}`, 'green');
                
                return true;
            } catch (error) {
                log(`❌ 铸造失败: ${error.message}`, 'red');
                return false;
            }
        }
        return true;
    }

    async approveTokens(amount, decimals) {
        const amountFormatted = ethers.formatUnits(amount, decimals);
        log(`\n🔑 授权银行合约使用 ${amountFormatted} tokens...`, 'cyan');
        
        try {
            const tx = await this.tokenContract.approve(CONTRACTS.TokenBankV4, amount);
            log(`📤 授权交易已发送: ${tx.hash}`, 'yellow');
            
            const receipt = await tx.wait();
            log(`✅ 授权成功! Gas 使用: ${receipt.gasUsed.toString()}`, 'green');
            
            return true;
        } catch (error) {
            log(`❌ 授权失败: ${error.message}`, 'red');
            return false;
        }
    }

    async depositTokens(amount, decimals) {
        const amountFormatted = ethers.formatUnits(amount, decimals);
        log(`\n💳 存款 ${amountFormatted} tokens 到银行...`, 'cyan');
        
        try {
            const tx = await this.bankContract.deposit(amount);
            log(`📤 存款交易已发送: ${tx.hash}`, 'yellow');
            
            const receipt = await tx.wait();
            log(`✅ 存款成功! Gas 使用: ${receipt.gasUsed.toString()}`, 'green');
            
            // 检查是否触发了事件
            if (receipt.logs.length > 0) {
                log(`📋 交易产生了 ${receipt.logs.length} 个事件`, 'blue');
            }
            
            return true;
        } catch (error) {
            log(`❌ 存款失败: ${error.message}`, 'red');
            return false;
        }
    }

    async checkAutomationStatus() {
        log('\n🤖 检查自动化状态...', 'cyan');
        
        try {
            // 检查银行状态
            const bankStatus = await this.automationContract.getBankStatus();
            const [totalDeposit, threshold, enabled, needsTransfer, transferAmount] = bankStatus;
            
            log(`📊 银行总存款: ${ethers.formatEther(totalDeposit)} tokens`, 'blue');
            log(`🎯 转移阈值: ${ethers.formatEther(threshold)} tokens`, 'blue');
            log(`🔄 自动转移启用: ${enabled ? '是' : '否'}`, 'blue');
            log(`⚡ 需要转移: ${needsTransfer ? '是' : '否'}`, needsTransfer ? 'red' : 'green');
            
            if (needsTransfer) {
                log(`💸 将转移金额: ${ethers.formatEther(transferAmount)} tokens`, 'red');
                log(`🎯 转移目标: ${CONTRACTS.owner}`, 'yellow');
            }
            
            // 检查 upkeep 状态
            const [upkeepNeeded] = await this.automationContract.checkUpkeep('0x');
            log(`🔧 Upkeep 需要执行: ${upkeepNeeded ? '是' : '否'}`, upkeepNeeded ? 'red' : 'green');
            
            return { needsTransfer, upkeepNeeded, transferAmount };
        } catch (error) {
            log(`❌ 检查自动化状态失败: ${error.message}`, 'red');
            return { needsTransfer: false, upkeepNeeded: false, transferAmount: 0n };
        }
    }

    async run() {
        try {
            log('🎯 TokenBankV4 存款脚本', 'magenta');
            log('='.repeat(50), 'magenta');
            
            // 初始化
            await this.initialize();
            
            // 检查配置
            const bankConfig = await this.checkBankConfiguration();
            const threshold = bankConfig.threshold;
            
            // 计算需要存款的金额 (阈值 + 100 tokens 以确保超过阈值)
            const extraAmount = ethers.parseEther('100'); // 额外100 tokens
            const depositAmount = threshold + extraAmount;
            const depositAmountFormatted = ethers.formatEther(depositAmount);
            
            log(`\n🎯 目标: 存款 ${depositAmountFormatted} tokens (超过 ${ethers.formatEther(threshold)} 阈值)`, 'magenta');
            
            // 检查当前余额
            const balances = await this.checkBalances();
            
            // 如果代币余额不足，铸造代币
            await this.mintTokensIfNeeded(depositAmount, balances.tokenBalance, balances.decimals);
            
            // 如果授权不足，进行授权
            if (balances.allowance < depositAmount) {
                await this.approveTokens(depositAmount, balances.decimals);
            }
            
            // 执行存款
            const success = await this.depositTokens(depositAmount, balances.decimals);
            
            if (success) {
                // 检查存款后的状态
                log('\n📊 存款后状态检查:', 'cyan');
                await this.checkBalances();
                
                // 检查自动化状态
                const automationStatus = await this.checkAutomationStatus();
                
                if (automationStatus.needsTransfer) {
                    log('\n🎉 成功! 存款已超过阈值，Chainlink Automation 将自动执行转移!', 'green');
                    log('⏰ 请等待 Chainlink Automation 检测并执行自动转移...', 'yellow');
                    log('🔗 您可以在 https://automation.chain.link/ 监控自动化执行状态', 'blue');
                } else {
                    log('\n ℹ️  存款完成，但未超过阈值或自动转移未启用', 'yellow');
                }
                
                // 保存操作日志
                await this.saveOperationLog(depositAmount, automationStatus);
            }
            
        } catch (error) {
            log(`❌ 脚本执行失败: ${error.message}`, 'red');
            console.error(error);
            process.exit(1);
        }
    }

    async saveOperationLog(depositAmount, automationStatus) {
        const logData = {
            timestamp: new Date().toISOString(),
            operation: 'deposit',
            user: this.signer.address,
            depositAmount: ethers.formatEther(depositAmount),
            contracts: CONTRACTS,
            automationStatus: {
                needsTransfer: automationStatus.needsTransfer,
                upkeepNeeded: automationStatus.upkeepNeeded,
                transferAmount: ethers.formatEther(automationStatus.transferAmount)
            }
        };
        
        const logFile = path.join(__dirname, '../deployLog/bankDepositLog.json');
        
        try {
            let logs = [];
            if (fs.existsSync(logFile)) {
                const content = fs.readFileSync(logFile, 'utf8');
                logs = JSON.parse(content);
            }
            
            logs.push(logData);
            fs.writeFileSync(logFile, JSON.stringify(logs, null, 2));
            
            log(`📝 操作日志已保存到: ${logFile}`, 'blue');
        } catch (error) {
            log(`⚠️  保存日志失败: ${error.message}`, 'yellow');
        }
    }
}

// 主函数
async function main() {
    const script = new BankDepositScript();
    await script.run();
}

// 错误处理
process.on('unhandledRejection', (error) => {
    console.error('Unhandled promise rejection:', error);
    process.exit(1);
});

// 如果直接运行此脚本
if (require.main === module) {
    main().catch(console.error);
}

module.exports = BankDepositScript;
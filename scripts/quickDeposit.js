const { ethers } = require('ethers');
require('dotenv').config();

// 合约地址和配置
const CONTRACTS = {
    TokenV3: '0x9CEAee8E52B76F4C296aF6293675fB9b797fd0Af',
    TokenBankV4: '0xe5c40B5F76700c3177E76c148D1A6b8569c69Bd9',
    BankAutomation: '0xBE3eb1794d87a9fCa05C603E95Bb91828C80Aec5',
    owner: '0xcC44277d1d6eC279Cd81e23111B1701758A3f82F'
};

// 简化的 ABI
const TOKEN_ABI = [
    "function mint(address to, uint256 amount) external",
    "function balanceOf(address account) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)"
];

const BANK_ABI = [
    "function deposit(uint256 amount) external",
    "function totalDeposit() external view returns (uint256)",
    "function autoTransferThreshold() external view returns (uint256)"
];

async function quickDeposit() {
    console.log('🎯 快速存款脚本 - TokenBankV4');
    console.log('='.repeat(40));
    
    // 设置连接
    const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    console.log(`👤 用户地址: ${signer.address}`);
    
    // 连接合约
    const token = new ethers.Contract(CONTRACTS.TokenV3, TOKEN_ABI, signer);
    const bank = new ethers.Contract(CONTRACTS.TokenBankV4, BANK_ABI, signer);
    
    try {
        // 1. 检查阈值
        const threshold = await bank.autoTransferThreshold();
        const thresholdTokens = ethers.formatEther(threshold);
        console.log(`🎯 自动转移阈值: ${thresholdTokens} tokens`);
        
        // 2. 计算存款金额 (阈值 + 200 tokens)
        const depositAmount = threshold + ethers.parseEther('200');
        const depositTokens = ethers.formatEther(depositAmount);
        console.log(`💰 计划存款: ${depositTokens} tokens`);
        
        // 3. 检查用户代币余额
        const balance = await token.balanceOf(signer.address);
        console.log(`📊 当前代币余额: ${ethers.formatEther(balance)} tokens`);
        
        // 4. 如果余额不足，铸造代币
        if (balance < depositAmount) {
            console.log('🪙 余额不足，正在铸造代币...');
            const mintTx = await token.mint(signer.address, depositAmount);
            console.log(`📤 铸造交易: ${mintTx.hash}`);
            await mintTx.wait();
            console.log('✅ 代币铸造成功!');
        }
        
        // 5. 检查授权
        const allowance = await token.allowance(signer.address, CONTRACTS.TokenBankV4);
        if (allowance < depositAmount) {
            console.log('🔑 正在授权银行合约...');
            const approveTx = await token.approve(CONTRACTS.TokenBankV4, depositAmount);
            console.log(`📤 授权交易: ${approveTx.hash}`);
            await approveTx.wait();
            console.log('✅ 授权成功!');
        }
        
        // 6. 执行存款
        console.log('💳 正在存款...');
        const depositTx = await bank.deposit(depositAmount);
        console.log(`📤 存款交易: ${depositTx.hash}`);
        await depositTx.wait();
        
        // 7. 检查结果
        const totalDeposit = await bank.totalDeposit();
        const totalTokens = ethers.formatEther(totalDeposit);
        
        console.log('✅ 存款成功!');
        console.log(`📈 银行总存款: ${totalTokens} tokens`);
        console.log(`🎯 阈值: ${thresholdTokens} tokens`);
        
        if (totalDeposit > threshold) {
            console.log('🎉 存款已超过阈值! Chainlink Automation 将自动执行转移!');
            console.log(`💸 将转移约 ${ethers.formatEther(totalDeposit / 2n)} tokens 给 owner`);
            console.log('⏰ 请等待自动化执行...');
        }
        
        console.log('\n📋 重要信息:');
        console.log(`- TokenV3: ${CONTRACTS.TokenV3}`);
        console.log(`- TokenBankV4: ${CONTRACTS.TokenBankV4}`);
        console.log(`- BankAutomation: ${CONTRACTS.BankAutomation}`);
        console.log(`- Owner: ${CONTRACTS.owner}`);
        
    } catch (error) {
        console.error('❌ 操作失败:', error.message);
        throw error;
    }
}

// 运行脚本
if (require.main === module) {
    quickDeposit()
        .then(() => {
            console.log('\n🎊 脚本执行完成!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('💥 脚本执行失败:', error);
            process.exit(1);
        });
}

module.exports = { quickDeposit, CONTRACTS };
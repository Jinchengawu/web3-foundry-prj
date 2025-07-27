const { ethers } = require('ethers');

// 示例：如何使用 permitDepositWithTokenPermit 功能（无需提前 approve）
async function permitDepositWithTokenPermitExample() {
    // 连接到以太坊网络
    const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
    
    // 用户私钥（在实际应用中，这应该由用户安全地管理）
    const userPrivateKey = 'YOUR_PRIVATE_KEY';
    const userWallet = new ethers.Wallet(userPrivateKey, provider);
    
    // 合约地址（部署后获得）
    const tokenBankAddress = 'TOKEN_BANK_CONTRACT_ADDRESS';
    const tokenAddress = 'TOKEN_CONTRACT_ADDRESS';
    
    // 合约 ABI（简化版）
    const tokenBankABI = [
        'function permitDepositWithTokenPermit(address owner, uint256 amount, uint256 deadline, uint8 tokenV, bytes32 tokenR, bytes32 tokenS, uint8 bankV, bytes32 bankR, bytes32 bankS)',
        'function DOMAIN_SEPARATOR() view returns (bytes32)',
        'function PERMIT_TYPEHASH() view returns (bytes32)'
    ];
    
    const tokenABI = [
        'function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
        'function nonces(address owner) view returns (uint256)',
        'function DOMAIN_SEPARATOR() view returns (bytes32)',
        'function PERMIT_TYPEHASH() view returns (bytes32)'
    ];
    
    const tokenBank = new ethers.Contract(tokenBankAddress, tokenBankABI, userWallet);
    const token = new ethers.Contract(tokenAddress, tokenABI, userWallet);
    
    // 存款参数
    const amount = ethers.utils.parseEther('100'); // 100 tokens
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
    
    try {
        // 1. 获取 TokenV3 的 nonce
        const tokenNonce = await token.nonces(userWallet.address);
        console.log('Token nonce:', tokenNonce.toString());
        
        // 2. 构建 TokenV3 permit 签名数据
        const tokenDomain = {
            name: await token.name(),
            version: '1',
            chainId: await provider.getNetwork().then(net => net.chainId),
            verifyingContract: tokenAddress
        };
        
        const tokenTypes = {
            Permit: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };
        
        const tokenMessage = {
            owner: userWallet.address,
            spender: tokenBankAddress,
            value: amount.toString(),
            nonce: tokenNonce.toString(),
            deadline: deadline.toString()
        };
        
        // 3. 创建 TokenV3 permit 签名
        console.log('Creating TokenV3 permit signature...');
        const tokenSignature = await userWallet._signTypedData(tokenDomain, tokenTypes, tokenMessage);
        const { v: tokenV, r: tokenR, s: tokenS } = ethers.utils.splitSignature(tokenSignature);
        
        // 4. 构建 TokenBankV3 permitDeposit 签名数据
        const bankDomain = {
            name: 'TokenBankV3',
            version: '1',
            chainId: await provider.getNetwork().then(net => net.chainId),
            verifyingContract: tokenBankAddress
        };
        
        const bankTypes = {
            PermitDeposit: [
                { name: 'owner', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };
        
        const bankMessage = {
            owner: userWallet.address,
            amount: amount.toString(),
            deadline: deadline.toString()
        };
        
        // 5. 创建 TokenBankV3 permitDeposit 签名
        console.log('Creating TokenBankV3 permitDeposit signature...');
        const bankSignature = await userWallet._signTypedData(bankDomain, bankTypes, bankMessage);
        const { v: bankV, r: bankR, s: bankS } = ethers.utils.splitSignature(bankSignature);
        
        // 6. 调用 permitDepositWithTokenPermit
        console.log('Executing permitDepositWithTokenPermit...');
        const permitTx = await tokenBank.permitDepositWithTokenPermit(
            userWallet.address,
            amount,
            deadline,
            tokenV,
            tokenR,
            tokenS,
            bankV,
            bankR,
            bankS
        );
        
        const receipt = await permitTx.wait();
        console.log('Permit deposit with token permit successful!');
        console.log('Transaction hash:', receipt.transactionHash);
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// 示例：对比两种方法的区别
function compareMethods() {
    console.log('=== 两种存款方法的对比 ===');
    console.log('');
    
    console.log('1. permitDeposit 方法：');
    console.log('   - 需要用户提前调用 token.approve() 进行授权');
    console.log('   - 只需要一套签名（用于 permitDeposit）');
    console.log('   - 用户需要发送两个交易：approve + permitDeposit');
    console.log('   - 或者用户提前 approve，然后只需要一个 permitDeposit 交易');
    console.log('');
    
    console.log('2. permitDepositWithTokenPermit 方法：');
    console.log('   - 无需用户提前调用 approve');
    console.log('   - 需要两套签名：TokenV3 permit + TokenBankV3 permitDeposit');
    console.log('   - 用户只需要发送一个交易');
    console.log('   - 在同一个交易中完成授权和存款');
    console.log('');
    
    console.log('推荐使用场景：');
    console.log('- 如果用户经常存款，建议使用 permitDeposit（提前 approve）');
    console.log('- 如果用户偶尔存款，建议使用 permitDepositWithTokenPermit（无需 approve）');
}

// 导出函数
module.exports = {
    permitDepositWithTokenPermitExample,
    compareMethods
};

// 如果直接运行此文件
if (require.main === module) {
    console.log('TokenBankV3 Permit Deposit With Token Permit Example');
    console.log('==================================================');
    compareMethods();
    console.log('请设置正确的环境变量和合约地址后运行 permitDepositWithTokenPermitExample()');
} 
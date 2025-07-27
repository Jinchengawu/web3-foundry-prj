const { ethers } = require('ethers');

// 示例：如何使用 depositWithPermit2 功能
async function depositWithPermit2Example() {
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
        'function depositWithPermit2(address owner, address tokenAddress, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
        'function DOMAIN_SEPARATOR() view returns (bytes32)'
    ];
    
    const tokenABI = [
        'function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
        'function nonces(address owner) view returns (uint256)',
        'function DOMAIN_SEPARATOR() view returns (bytes32)',
        'function PERMIT_TYPEHASH() view returns (bytes32)',
        'function name() view returns (string)'
    ];
    
    const tokenBank = new ethers.Contract(tokenBankAddress, tokenBankABI, userWallet);
    const token = new ethers.Contract(tokenAddress, tokenABI, userWallet);
    
    // 存款参数
    const amount = ethers.utils.parseEther('100'); // 100 tokens
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
    
    try {
        // 1. 获取代币的 nonce
        const tokenNonce = await token.nonces(userWallet.address);
        console.log('Token nonce:', tokenNonce.toString());
        
        // 2. 构建代币的 permit 签名数据
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
        
        // 3. 创建代币的 permit 签名
        console.log('Creating token permit signature...');
        const tokenSignature = await userWallet._signTypedData(tokenDomain, tokenTypes, tokenMessage);
        const { v, r, s } = ethers.utils.splitSignature(tokenSignature);
        
        // 4. 调用 depositWithPermit2
        console.log('Executing depositWithPermit2...');
        const depositTx = await tokenBank.depositWithPermit2(
            userWallet.address,
            tokenAddress,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        const receipt = await depositTx.wait();
        console.log('Deposit with permit2 successful!');
        console.log('Transaction hash:', receipt.transactionHash);
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// 示例：处理不支持 permit 的代币
async function depositWithPermit2ForNonPermitToken() {
    // 对于不支持 permit 的代币，用户需要提前 approve
    const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
    const userPrivateKey = 'YOUR_PRIVATE_KEY';
    const userWallet = new ethers.Wallet(userPrivateKey, provider);
    
    const tokenBankAddress = 'TOKEN_BANK_CONTRACT_ADDRESS';
    const tokenAddress = 'NON_PERMIT_TOKEN_ADDRESS';
    
    const tokenBankABI = [
        'function depositWithPermit2(address owner, address tokenAddress, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)'
    ];
    
    const tokenABI = [
        'function approve(address spender, uint256 amount) returns (bool)',
        'function transferFrom(address from, address to, uint256 amount) returns (bool)'
    ];
    
    const tokenBank = new ethers.Contract(tokenBankAddress, tokenBankABI, userWallet);
    const token = new ethers.Contract(tokenAddress, tokenABI, userWallet);
    
    const amount = ethers.utils.parseEther('100');
    const deadline = Math.floor(Date.now() / 1000) + 3600;
    
    try {
        // 1. 首先授权 TokenBank 使用代币
        console.log('Approving tokens...');
        const approveTx = await token.approve(tokenBankAddress, amount);
        await approveTx.wait();
        console.log('Tokens approved');
        
        // 2. 调用 depositWithPermit2（permit 会失败，但 transferFrom 会成功）
        console.log('Executing depositWithPermit2...');
        const depositTx = await tokenBank.depositWithPermit2(
            userWallet.address,
            tokenAddress,
            amount,
            deadline,
            0, // 无效的签名参数
            0,
            0
        );
        
        const receipt = await depositTx.wait();
        console.log('Deposit with permit2 successful!');
        console.log('Transaction hash:', receipt.transactionHash);
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// 示例：对比不同的存款方法
function compareDepositMethods() {
    console.log('=== 三种存款方法的对比 ===');
    console.log('');
    
    console.log('1. 传统 deposit 方法：');
    console.log('   - 需要用户提前调用 token.approve()');
    console.log('   - 用户需要发送两个交易：approve + deposit');
    console.log('   - 适用于所有 ERC20 代币');
    console.log('');
    
    console.log('2. permitDeposit 方法：');
    console.log('   - 需要用户提前调用 token.approve()');
    console.log('   - 只需要一个交易（如果已 approve）');
    console.log('   - 适用于所有 ERC20 代币');
    console.log('');
    
    console.log('3. depositWithPermit2 方法：');
    console.log('   - 支持 permit 的代币：无需提前 approve');
    console.log('   - 不支持 permit 的代币：需要提前 approve');
    console.log('   - 只需要一个交易');
    console.log('   - 适用于所有 ERC20 代币');
    console.log('');
    
    console.log('推荐使用场景：');
    console.log('- 代币支持 permit：使用 depositWithPermit2');
    console.log('- 代币不支持 permit：使用 permitDeposit（提前 approve）');
    console.log('- 简单场景：使用传统 deposit 方法');
}

// 导出函数
module.exports = {
    depositWithPermit2Example,
    depositWithPermit2ForNonPermitToken,
    compareDepositMethods
};

// 如果直接运行此文件
if (require.main === module) {
    console.log('TokenBankV3 Deposit With Permit2 Example');
    console.log('========================================');
    compareDepositMethods();
    console.log('请设置正确的环境变量和合约地址后运行 depositWithPermit2Example()');
} 
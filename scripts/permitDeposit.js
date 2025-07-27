const { ethers } = require('ethers');

// 示例：如何使用 permitDeposit 功能
async function permitDepositExample() {
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
        'function permitDeposit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
        'function DOMAIN_SEPARATOR() view returns (bytes32)',
        'function PERMIT_TYPEHASH() view returns (bytes32)'
    ];
    
    const tokenABI = [
        'function approve(address spender, uint256 amount) returns (bool)',
        'function transferFrom(address from, address to, uint256 amount) returns (bool)'
    ];
    
    const tokenBank = new ethers.Contract(tokenBankAddress, tokenBankABI, userWallet);
    const token = new ethers.Contract(tokenAddress, tokenABI, userWallet);
    
    // 存款参数
    const amount = ethers.utils.parseEther('100'); // 100 tokens
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
    
    try {
        // 1. 首先授权 TokenBank 使用用户的代币
        console.log('Approving tokens...');
        const approveTx = await token.approve(tokenBankAddress, amount);
        await approveTx.wait();
        console.log('Tokens approved');
        
        // 2. 获取合约的域分隔符和类型哈希
        const domainSeparator = await tokenBank.DOMAIN_SEPARATOR();
        const permitTypeHash = await tokenBank.PERMIT_TYPEHASH();
        
        // 3. 构建 EIP-712 签名数据
        const domain = {
            name: 'TokenBankV3',
            version: '1',
            chainId: await provider.getNetwork().then(net => net.chainId),
            verifyingContract: tokenBankAddress
        };
        
        const types = {
            PermitDeposit: [
                { name: 'owner', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'deadline', type: 'uint256' }
            ]
        };
        
        const message = {
            owner: userWallet.address,
            amount: amount.toString(),
            deadline: deadline.toString()
        };
        
        // 4. 创建签名
        console.log('Creating signature...');
        const signature = await userWallet._signTypedData(domain, types, message);
        const { v, r, s } = ethers.utils.splitSignature(signature);
        
        // 5. 调用 permitDeposit
        console.log('Executing permitDeposit...');
        const permitTx = await tokenBank.permitDeposit(
            userWallet.address,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        const receipt = await permitTx.wait();
        console.log('Permit deposit successful!');
        console.log('Transaction hash:', receipt.transactionHash);
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// 示例：如何验证签名（在合约中）
function verifySignatureExample() {
    // 这是合约中验证签名的逻辑
    const domainSeparator = '0x...'; // 从合约获取
    const permitTypeHash = '0x...'; // 从合约获取
    
    const owner = '0x...'; // 用户地址
    const amount = '100000000000000000000'; // 100 tokens (wei)
    const deadline = '1234567890'; // 时间戳
    
    // 构建结构体哈希
    const structHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'address', 'uint256', 'uint256'],
            [permitTypeHash, owner, amount, deadline]
        )
    );
    
    // 构建完整的 EIP-712 哈希
    const hash = ethers.utils.keccak256(
        ethers.utils.solidityPack(
            ['string', 'bytes32', 'bytes32'],
            ['\x19\x01', domainSeparator, structHash]
        )
    );
    
    // 从签名中恢复签名者地址
    const v = 27; // 签名 v 值
    const r = '0x...'; // 签名 r 值
    const s = '0x...'; // 签名 s 值
    
    const signer = ethers.utils.recoverAddress(hash, { v, r, s });
    console.log('Recovered signer:', signer);
    console.log('Expected owner:', owner);
    console.log('Signature valid:', signer.toLowerCase() === owner.toLowerCase());
}

// 导出函数
module.exports = {
    permitDepositExample,
    verifySignatureExample
};

// 如果直接运行此文件
if (require.main === module) {
    console.log('TokenBankV3 Permit Deposit Example');
    console.log('==================================');
    console.log('请设置正确的环境变量和合约地址后运行 permitDepositExample()');
} 
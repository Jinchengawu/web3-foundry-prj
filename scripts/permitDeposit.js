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

// 示例：如何使用 permitDepositWithTokenPermit 功能（推荐）
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
        'function permitDepositWithTokenPermit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
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
        
        // 4. 调用 permitDepositWithTokenPermit（只需要一套签名）
        console.log('Executing permitDepositWithTokenPermit...');
        const permitTx = await tokenBank.permitDepositWithTokenPermit(
            userWallet.address,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        const receipt = await permitTx.wait();
        console.log('Permit deposit with token permit successful!');
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

// 示例：对比不同的存款方法
function compareDepositMethods() {
    console.log('=== 三种存款方法的对比 ===');
    console.log('');
    
    console.log('1. permitDeposit 方法：');
    console.log('   - 需要用户提前调用 token.approve()');
    console.log('   - 只需要一套签名（用于 permitDeposit）');
    console.log('   - 用户需要发送两个交易：approve + permitDeposit');
    console.log('   - 或者用户提前 approve，然后只需要一个 permitDeposit 交易');
    console.log('');
    
    console.log('2. permitDepositWithTokenPermit 方法（推荐）：');
    console.log('   - 无需用户提前调用 approve');
    console.log('   - 只需要一套签名（用于代币的 permit）');
    console.log('   - 用户只需要发送一个交易');
    console.log('   - 在同一个交易中完成授权和存款');
    console.log('');
    
    console.log('3. depositWithPermit2 方法：');
    console.log('   - 支持任何 ERC20 代币');
    console.log('   - 自动检测代币是否支持 permit');
    console.log('   - 只需要一套签名');
    console.log('   - 最通用的解决方案');
    console.log('');
    
    console.log('推荐使用场景：');
    console.log('- 使用 TokenV3 代币：使用 permitDepositWithTokenPermit');
    console.log('- 使用其他支持 permit 的代币：使用 depositWithPermit2');
    console.log('- 使用不支持 permit 的代币：使用 permitDeposit（提前 approve）');
}

// 导出函数
module.exports = {
    permitDepositExample,
    permitDepositWithTokenPermitExample,
    verifySignatureExample,
    compareDepositMethods
};

// 如果直接运行此文件
if (require.main === module) {
    console.log('TokenBankV3 Permit Deposit Examples');
    console.log('===================================');
    compareDepositMethods();
    console.log('请设置正确的环境变量和合约地址后运行相应的示例函数');
} 
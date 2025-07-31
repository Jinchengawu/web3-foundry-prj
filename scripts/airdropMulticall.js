const { ethers } = require('ethers');

// AirdopMerkleNFTMarket 合约 ABI（简化版本）
const ABI = [
    "function permitPrePay(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)",
    "function claimNFT(string memory listingId, uint256 maxAmount, bytes32[] calldata merkleProof)",
    "function multicall(bytes[] calldata data) external returns (bytes[] memory results)",
    "function verifyMerkleProof(address account, uint256 maxAmount, bytes32[] calldata merkleProof) public view returns (bool)",
    "function calculateDiscountedPrice(uint256 originalPrice) public pure returns (uint256)"
];

// TokenV3 合约 ABI（简化版本）
const TOKEN_ABI = [
    "function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)",
    "function DOMAIN_SEPARATOR() public view returns (bytes32)",
    "function getNonce(address owner) public view returns (uint256)"
];

class AirdropMulticallHelper {
    constructor(contractAddress, tokenAddress, provider, signer) {
        this.contract = new ethers.Contract(contractAddress, ABI, signer);
        this.token = new ethers.Contract(tokenAddress, TOKEN_ABI, signer);
        this.provider = provider;
        this.signer = signer;
    }

    /**
     * 生成 permit 签名
     * @param {string} owner 代币持有者地址
     * @param {string} spender 被授权者地址
     * @param {string} value 授权金额
     * @param {number} deadline 过期时间
     * @param {string} privateKey 私钥
     * @returns {Object} 签名参数
     */
    async generatePermitSignature(owner, spender, value, deadline, privateKey) {
        const domainSeparator = await this.token.DOMAIN_SEPARATOR();
        const nonce = await this.token.getNonce(owner);
        
        const permitTypeHash = ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        );
        
        const structHash = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
                [permitTypeHash, owner, spender, value, nonce, deadline]
            )
        );
        
        const hash = ethers.utils.keccak256(
            ethers.utils.solidityPack(
                ['string', 'bytes32', 'bytes32'],
                ['\x19\x01', domainSeparator, structHash]
            )
        );
        
        const wallet = new ethers.Wallet(privateKey);
        const signature = wallet.signMessage(ethers.utils.arrayify(hash));
        
        const { v, r, s } = ethers.utils.splitSignature(signature);
        
        return { v, r, s };
    }

    /**
     * 构建 multicall 数据
     * @param {string} listingId 上架 ID
     * @param {number} maxAmount 最大可领取数量
     * @param {Array} merkleProof Merkle 证明
     * @param {Object} permitParams permit 参数
     * @returns {Array} multicall 数据
     */
    buildMulticallData(listingId, maxAmount, merkleProof, permitParams) {
        const { v, r, s } = permitParams;
        
        // permitPrePay 调用数据
        const permitData = this.contract.interface.encodeFunctionData('permitPrePay', [
            permitParams.owner,
            permitParams.spender,
            permitParams.value,
            permitParams.deadline,
            v,
            r,
            s
        ]);
        
        // claimNFT 调用数据
        const claimData = this.contract.interface.encodeFunctionData('claimNFT', [
            listingId,
            maxAmount,
            merkleProof
        ]);
        
        return [permitData, claimData];
    }

    /**
     * 执行 multicall
     * @param {Array} calls 调用数据数组
     * @returns {Promise} 交易结果
     */
    async executeMulticall(calls) {
        const tx = await this.contract.multicall(calls);
        const receipt = await tx.wait();
        return receipt;
    }

    /**
     * 完整的白名单购买流程
     * @param {string} listingId 上架 ID
     * @param {number} maxAmount 最大可领取数量
     * @param {Array} merkleProof Merkle 证明
     * @param {string} privateKey 用户私钥
     * @returns {Promise} 交易结果
     */
    async executeWhitelistPurchase(listingId, maxAmount, merkleProof, privateKey) {
        const owner = await this.signer.getAddress();
        const spender = this.contract.address;
        const value = ethers.utils.parseEther("500"); // 假设优惠价格为 500 tokens
        const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
        
        // 生成 permit 签名
        const permitParams = await this.generatePermitSignature(
            owner, spender, value, deadline, privateKey
        );
        
        // 构建 multicall 数据
        const calls = this.buildMulticallData(listingId, maxAmount, merkleProof, {
            owner,
            spender,
            value,
            deadline,
            ...permitParams
        });
        
        // 执行 multicall
        return await this.executeMulticall(calls);
    }

    /**
     * 验证 Merkle 证明
     * @param {string} account 用户地址
     * @param {number} maxAmount 最大可领取数量
     * @param {Array} merkleProof Merkle 证明
     * @returns {Promise<boolean>} 验证结果
     */
    async verifyMerkleProof(account, maxAmount, merkleProof) {
        return await this.contract.verifyMerkleProof(account, maxAmount, merkleProof);
    }

    /**
     * 计算优惠价格
     * @param {string} originalPrice 原始价格
     * @returns {Promise<string>} 优惠价格
     */
    async calculateDiscountedPrice(originalPrice) {
        return await this.contract.calculateDiscountedPrice(originalPrice);
    }
}

// 使用示例
async function main() {
    // 配置
    const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
    const privateKey = 'YOUR_PRIVATE_KEY';
    const signer = new ethers.Wallet(privateKey, provider);
    
    const contractAddress = 'DEPLOYED_CONTRACT_ADDRESS';
    const tokenAddress = 'DEPLOYED_TOKEN_ADDRESS';
    
    const helper = new AirdropMulticallHelper(contractAddress, tokenAddress, provider, signer);
    
    // 示例参数
    const listingId = 'example_listing_id';
    const maxAmount = 2;
    const merkleProof = []; // 实际使用时需要提供真实的 Merkle 证明
    
    try {
        // 验证 Merkle 证明
        const isValid = await helper.verifyMerkleProof(
            await signer.getAddress(),
            maxAmount,
            merkleProof
        );
        console.log('Merkle proof valid:', isValid);
        
        // 计算优惠价格
        const originalPrice = ethers.utils.parseEther("1000");
        const discountedPrice = await helper.calculateDiscountedPrice(originalPrice);
        console.log('Discounted price:', ethers.utils.formatEther(discountedPrice));
        
        // 执行白名单购买（需要有效的 Merkle 证明）
        if (isValid) {
            const result = await helper.executeWhitelistPurchase(
                listingId,
                maxAmount,
                merkleProof,
                privateKey
            );
            console.log('Purchase successful:', result.transactionHash);
        }
        
    } catch (error) {
        console.error('Error:', error);
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main().catch(console.error);
}

module.exports = AirdropMulticallHelper; 
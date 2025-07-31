const { ethers } = require('ethers');

// 简化的 multicall 演示
class AirdropDemo {
    constructor(contractAddress, tokenAddress, provider, signer) {
        this.contract = new ethers.Contract(contractAddress, [
            "function permitPrePay(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)",
            "function claimNFT(string memory listingId, uint256 maxAmount, bytes32[] calldata merkleProof)",
            "function multicall(bytes[] calldata data) external returns (bytes[] memory results)"
        ], signer);
        
        this.token = new ethers.Contract(tokenAddress, [
            "function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)"
        ], signer);
    }

    async executeMulticall(permitData, claimData) {
        const calls = [permitData, claimData];
        const tx = await this.contract.multicall(calls);
        return await tx.wait();
    }
}

module.exports = AirdropDemo; 
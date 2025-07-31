// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {AirdopMerkleNFTMarket} from "../src/W4/D4/AirdopMerkleNFTMarket.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";
import {BaseERC721} from "../src/W2/D3/ERC721_NFT.sol";

contract AirdopMerkleNFTMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署代币合约
        TokenV3 token = new TokenV3("AirdropToken", "AT");
        console2.log("Token deployed at:", address(token));

        // 部署 NFT 合约
        BaseERC721 nft = new BaseERC721("AirdropNFT", "ANFT", "https://api.example.com/metadata/");
        console2.log("NFT deployed at:", address(nft));

        // 示例 Merkle 树根（实际使用时需要根据白名单生成）
        bytes32 merkleRoot = keccak256(abi.encodePacked(address(0x123), uint256(2)));
        
        // 部署市场合约
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(address(token), merkleRoot);
        console2.log("AirdopMerkleNFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
} 
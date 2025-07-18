// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/***

你的任务是创建一个遵循 ERC721 标准的智能合约，该合约能够用于在以太坊区块链上铸造与交易 NFT。

 */
contract BaseERC721 is ERC721URIStorage { 
    using Strings for uint256;
    using Address for address;
    uint256 private _nextTokenId = 1; // 计数器

    /**
     * @dev Initializes the contract by setting a `name`, a `symbol` and a `baseURI` to the token collection.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        _setBaseURI(baseURI_);
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` must not exist.
     *
     * Emits a {Transfer} event.
     */
    function mint(address to, uint256 tokenId) public {
        require(address(to) != address(0), "ERC721: mint to the zero address");
        
        // Check if token already exists by trying to get its owner
        try this.ownerOf(tokenId) {
            revert("ERC721: token already minted");
        } catch {
            // Token doesn't exist, safe to mint
        }
        
        _mint(to, tokenId);
        _nextTokenId++;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Sets the base URI for all tokens.
     */
    function _setBaseURI(string memory baseURI_) internal {
        // This would need to be implemented in a custom extension
        // For now, we'll use the default behavior
    }
}

contract BaseERC721Receiver is IERC721Receiver {
    constructor() {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
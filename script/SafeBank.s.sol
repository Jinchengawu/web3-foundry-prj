// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/W3/D3/SafeBank.sol";
import "../src/W2/D3/ERC20_Plus.sol";

contract SafeBankScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署ERC20V2代币
        ERC20V2 token = new ERC20V2("SafeBank Token", "SBT");
        console.log("ERC20V2 Token deployed at:", address(token));

        // 2. 部署SafeBank合约
        SafeBank safeBank = new SafeBank(token);
        console.log("SafeBank deployed at:", address(safeBank));

        // 3. 为部署者铸造一些代币
        token.mint(vm.addr(deployerPrivateKey), 1000000 * 10**18);
        console.log("Minted 1,000,000 tokens to deployer");

        vm.stopBroadcast();
    }
} 
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenBankV2} from "../src/W2/D3/TokenBank_Plus.sol";
import {ERC20V2} from "../src/W2/D3/ERC20_Plus.sol";

contract DeployTokenBank is Script {
    TokenBankV2 public counter;

    ERC20V2 public token;

    function setUp() public {
        token = new ERC20V2("MyToken", "MTK");
    }

    function run() public {
        vm.startBroadcast();

        counter = new TokenBankV2(token);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20V2} from "../src/W2/D3/ERC20_Plus.sol";

contract DeployMyToken is Script {
    ERC20V2 public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        counter = new ERC20V2("MyToken", "MTK");

        vm.stopBroadcast();
    }
}

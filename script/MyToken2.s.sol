// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyToken2} from "../src/W2/D4/MyToken2.sol";

contract DeployMyToken is Script {
    MyToken2 public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        counter = new MyToken2();

        vm.stopBroadcast();
    }
}

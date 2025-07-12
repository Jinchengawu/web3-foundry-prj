// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";
// import {Bank} from "../../../src/W1/D3/Bank.sol";

// contract Bank_Test is Test {
//     Bank public bank = new Bank();
//     function getMsgAddress()public view returns (address) {
//         return msg.sender;
//     }

//     receive() external payable{

//     }

   
//    function test_deposit() public payable{
//     bank.deposit{value: 1 ether}();
//     assertEq( address(bank).balance, 1 ether);
//    }

//    function test_withdraw() public payable{
//     bank.changeOwner();
//     bank.deposit{value: 1 ether}();
//     assertEq(address(bank).balance, 1 ether);
//     bank.withdraw(address(this),address(this), 0.5 ether);
//     // assertEq(bank.getBalance(), 0,5);
//    }

// }

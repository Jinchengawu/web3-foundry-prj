// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import "../src/W1/D4/BigBankWrapper.sol";
// import "../src/W1/D4/Bigbank2.sol";

// contract BigBankDeployScript is Script {
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         // 部署BigBankWrapper合约
//         BigBankWrapper bigBankWrapper = new BigBankWrapper();
//         console.log("BigBankWrapper deployed at:", address(bigBankWrapper));
//         console.log("BigBank deployed at:", bigBankWrapper.getBigBankAddress());

//         // 部署Admin合约
//         Admin admin = new Admin();
//         console.log("Admin deployed at:", address(admin));

//         // 模拟几个用户存款到BigBankWrapper
//         address user1 = vm.addr(1);
//         address user2 = vm.addr(2);
//         address user3 = vm.addr(3);

//         // 用户1存款 0.002 ether
//         vm.prank(user1);
//         bigBankWrapper.deposit{value: 0.002 ether}();
//         console.log("User1 deposited 0.002 ether");

//         // 用户2存款 0.005 ether
//         vm.prank(user2);
//         bigBankWrapper.deposit{value: 0.005 ether}();
//         console.log("User2 deposited 0.005 ether");

//         // 用户3存款 0.003 ether
//         vm.prank(user3);
//         bigBankWrapper.deposit{value: 0.003 ether}();
//         console.log("User3 deposited 0.003 ether");

//         console.log("BigBank balance after deposits:", bigBankWrapper.getBigBankBalance());

//         // 将BigBankWrapper的管理员转移给Admin合约
//         bigBankWrapper.transferOwnership(address(admin));
//         console.log("BigBankWrapper ownership transferred to Admin contract");

//         // Admin合约的owner调用adminWithdraw，将BigBankWrapper的资金转移到Admin
//         address adminOwner = admin.owner();
//         vm.prank(adminOwner);
//         admin.adminWithdraw(IBank(address(bigBankWrapper)));
//         console.log("Admin withdrew all funds from BigBankWrapper");

//         console.log("Admin contract balance:", admin.getBalance());
//         console.log("BigBank balance after withdrawal:", bigBankWrapper.getBigBankBalance());

//         // Admin合约的owner提取资金到自己的地址
//         vm.prank(adminOwner);
//         admin.withdrawFunds(admin.getBalance());
//         console.log("Admin owner withdrew all funds from Admin contract");

//         vm.stopBroadcast();
//     }
// } 
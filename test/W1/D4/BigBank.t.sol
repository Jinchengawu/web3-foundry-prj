// // SPDX-License-Identifier: MIT
// pragma solidity^0.8.13;

// import "forge-std/Test.sol";
// import "../../src/W1/D4/BigBankWrapper.sol";
// import "../../src/W1/D4/Bigbank2.sol";

// contract BigBankTest is Test {
//     BigBankWrapper public bigBankWrapper;
//     BigBank public bigBank;
//     Admin public admin;
//     address public user1;
//     address public user2;
//     address public user3;
//     address public deployer;

//     function setUp() public {
//         deployer = address(this);
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         user3 = makeAddr("user3");

//         bigBankWrapper = new BigBankWrapper();
//         bigBank = bigBankWrapper.bigBank();
//         admin = new Admin();
//     }

//     function testDepositMinimumAmount() public {
//         // 测试存款金额小于0.001 ether应该失败
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         vm.expectRevert("Deposit must be at least 0.001 ether");
//         bigBankWrapper.deposit{value: 0.0005 ether}();
//     }

//     function testDepositValidAmount() public {
//         // 测试存款金额等于0.001 ether应该成功
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         bigBankWrapper.deposit{value: 0.001 ether}();
        
//         // 验证BigBank合约余额
//         assertEq(bigBankWrapper.getBigBankBalance(), 0.001 ether);
//     }

//     function testTransferOwnership() public {
//         // 测试转移所有权
//         bigBankWrapper.transferOwnership(address(admin));
//         assertEq(bigBankWrapper.owner(), address(admin));
//     }

//     function testTransferOwnershipOnlyOwner() public {
//         // 测试非owner不能转移所有权
//         vm.prank(user1);
//         vm.expectRevert("Only owner can call this function");
//         bigBankWrapper.transferOwnership(user1);
//     }

//     function testAdminWithdraw() public {
//         // 设置初始状态
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         bigBankWrapper.deposit{value: 0.002 ether}();

//         // 转移BigBankWrapper所有权给Admin
//         bigBankWrapper.transferOwnership(address(admin));

//         // Admin的owner调用adminWithdraw
//         address adminOwner = admin.owner();
//         vm.prank(adminOwner);
//         admin.adminWithdraw(IBank(address(bigBankWrapper)));

//         // 验证资金已转移到Admin合约
//         assertEq(admin.getBalance(), 0.002 ether);
//         assertEq(bigBankWrapper.getBigBankBalance(), 0);
//     }

//     function testAdminWithdrawOnlyOwner() public {
//         // 测试非Admin owner不能调用adminWithdraw
//         vm.prank(user1);
//         vm.expectRevert("Only owner can call this function");
//         admin.adminWithdraw(IBank(address(bigBankWrapper)));
//     }

//     function testCompleteFlow() public {
//         // 完整流程测试
//         vm.deal(user1, 1 ether);
//         vm.deal(user2, 1 ether);
//         vm.deal(user3, 1 ether);

//         // 用户存款
//         vm.prank(user1);
//         bigBankWrapper.deposit{value: 0.002 ether}();

//         vm.prank(user2);
//         bigBankWrapper.deposit{value: 0.005 ether}();

//         vm.prank(user3);
//         bigBankWrapper.deposit{value: 0.003 ether}();

//         // 验证总余额
//         assertEq(bigBankWrapper.getBigBankBalance(), 0.01 ether);

//         // 转移所有权
//         bigBankWrapper.transferOwnership(address(admin));

//         // Admin提取资金
//         address adminOwner = admin.owner();
//         vm.prank(adminOwner);
//         admin.adminWithdraw(IBank(address(bigBankWrapper)));

//         // 验证资金转移
//         assertEq(admin.getBalance(), 0.01 ether);
//         assertEq(bigBankWrapper.getBigBankBalance(), 0);

//         // Admin owner提取资金到自己的地址
//         uint256 adminOwnerBalanceBefore = adminOwner.balance;
//         vm.prank(adminOwner);
//         admin.withdrawFunds(0.01 ether);

//         // 验证Admin owner收到了资金
//         assertEq(adminOwner.balance, adminOwnerBalanceBefore + 0.01 ether);
//         assertEq(admin.getBalance(), 0);
//     }

//     function testReceiveFunction() public {
//         // 测试receive函数的最小存款限制
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
        
//         // 发送小于0.001 ether应该失败
//         vm.expectRevert("Deposit must be at least 0.001 ether");
//         (bool success,) = address(bigBankWrapper).call{value: 0.0005 ether}("");
//         assertFalse(success);

//         // 发送等于0.001 ether应该成功
//         (success,) = address(bigBankWrapper).call{value: 0.001 ether}("");
//         assertTrue(success);
//         assertEq(bigBankWrapper.getBigBankBalance(), 0.001 ether);
//     }
// } 
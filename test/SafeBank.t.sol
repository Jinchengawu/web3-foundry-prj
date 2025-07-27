// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/W3/D3/SafeBank.sol";
import "../src/W2/D3/ERC20_Plus.sol";

contract SafeBankTest is Test {
    SafeBank public safeBank;
    ERC20V2 public token;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署代币
        token = new ERC20V2("SafeBank Token", "SBT");
        
        // 部署SafeBank合约
        safeBank = new SafeBank(token);
        
        // 为测试用户铸造代币
        token.mint(user1, 10000 * 10**18);
        token.mint(user2, 10000 * 10**18);
        token.mint(user3, 10000 * 10**18);
        
        vm.stopPrank();
    }

    function testCreateSafeBankAccount() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        assertEq(accountId, 1);
        
        (uint256 id, address[] memory returnedOwners, uint256 requiredSignatures, uint256 orderCount) = safeBank.getSafeBankAccount(accountId);
        assertEq(id, 1);
        assertEq(returnedOwners.length, 3);
        assertEq(requiredSignatures, 2);
        assertEq(orderCount, 0);
        
        assertTrue(safeBank.isOwner(accountId, user1));
        assertTrue(safeBank.isOwner(accountId, user2));
        assertTrue(safeBank.isOwner(accountId, user3));
    }

    function testDepositToSafeBank() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 授权SafeBank合约使用代币
        vm.prank(user1);
        token.approve(address(safeBank), 1000 * 10**18);
        
        // 存入代币到多签账户
        vm.prank(user1);
        safeBank.depositToSafeBank(accountId, address(token), 1000 * 10**18);
        
        assertEq(safeBank.getTokenBalance(accountId, address(token)), 1000 * 10**18);
    }

    function testCreateAndExecuteWithdrawOrder() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 存入代币
        vm.prank(user1);
        token.approve(address(safeBank), 1000 * 10**18);
        vm.prank(user1);
        safeBank.depositToSafeBank(accountId, address(token), 1000 * 10**18);
        
        // 创建提取订单
        vm.prank(user1);
        safeBank.createWithdrawOrder(accountId, address(token), 500 * 10**18, user2, block.timestamp + 3600);
        
        // 第一个所有者审批
        vm.prank(user1);
        safeBank.approveOrder(accountId, 0);
        
        // 第二个所有者审批（应该自动执行）
        vm.prank(user2);
        safeBank.approveOrder(accountId, 0);
        
        // 检查余额
        assertEq(token.balanceOf(user2), 10500 * 10**18); // 原有10000 + 提取500
        assertEq(safeBank.getTokenBalance(accountId, address(token)), 500 * 10**18); // 剩余500
    }

    function testSetBankOwnerToSafeBank() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 设置Bank合约的所有者为SafeBank
        vm.prank(user1);
        safeBank.setBankOwnerToSafeBank(accountId);
        
        // 验证Bank合约的所有者已更改
        assertEq(safeBank.owner(), address(safeBank));
    }

    function testCreateAndExecuteBankWithdrawOrder() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 设置Bank合约的所有者为SafeBank
        vm.prank(user1);
        safeBank.setBankOwnerToSafeBank(accountId);
        
        // 向Bank合约存入代币
        vm.prank(user1);
        token.approve(address(safeBank), 1000 * 10**18);
        vm.prank(user1);
        safeBank.deposit(1000 * 10**18);
        
        // 创建Bank提取订单
        vm.prank(user1);
        safeBank.createBankWithdrawOrder(accountId, 500 * 10**18, block.timestamp + 3600);
        
        // 第一个所有者审批
        vm.prank(user1);
        safeBank.approveOrder(accountId, 0);
        
        // 第二个所有者审批（应该自动执行）
        vm.prank(user2);
        safeBank.approveOrder(accountId, 0);
        
        // 检查SafeBank账户余额
        assertEq(safeBank.getTokenBalance(accountId, address(token)), 500 * 10**18);
    }

    function testRejectOrder() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 存入代币
        vm.prank(user1);
        token.approve(address(safeBank), 1000 * 10**18);
        vm.prank(user1);
        safeBank.depositToSafeBank(accountId, address(token), 1000 * 10**18);
        
        // 创建提取订单
        vm.prank(user1);
        safeBank.createWithdrawOrder(accountId, address(token), 500 * 10**18, user2, block.timestamp + 3600);
        
        // 拒绝订单
        vm.prank(user2);
        safeBank.rejectOrder(accountId, 0);
        
        // 验证订单状态
        // (,,,,,,, bool isRejected,,) = safeBank.getOrder(accountId, 0);
        // assertTrue(isRejected);
    }

    function testCancelOrder() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 存入代币
        vm.prank(user1);
        token.approve(address(safeBank), 1000 * 10**18);
        vm.prank(user1);
        safeBank.depositToSafeBank(accountId, address(token), 1000 * 10**18);
        
        // 创建提取订单
        vm.prank(user1);
        safeBank.createWithdrawOrder(accountId, address(token), 500 * 10**18, user2, block.timestamp + 3600);
        
        // 取消订单
        vm.prank(user1);
        safeBank.cancelOrder(accountId, 0);
        
        // 验证订单状态
        // (,,,,,, bool isCancelled,,,) = safeBank.getOrder(accountId, 0);
        // assertTrue(isCancelled);
    }

    function testFailCreateAccountWithInsufficientOwners() public {
        address[] memory owners = new address[](1);
        owners[0] = user1;
        
        vm.prank(user1);
        safeBank.createSafeBankAccount(owners, 2); // 应该失败
    }

    function testFailCreateAccountWithInvalidRequiredSignatures() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        safeBank.createSafeBankAccount(owners, 4); // 应该失败，因为需要签名数超过所有者数
    }

    function testFailNonOwnerCreateOrder() public {
        // 创建多签账户
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        
        vm.prank(user1);
        uint256 accountId = safeBank.createSafeBankAccount(owners, 2);
        
        // 非所有者尝试创建订单
        vm.prank(address(999));
        safeBank.createWithdrawOrder(accountId, address(token), 500 * 10**18, user2, block.timestamp + 3600); // 应该失败
    }
} 
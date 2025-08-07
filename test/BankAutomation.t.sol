// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/W5/D3/TokenBankV4.sol";
import "../src/W5/D3/Automation-compatible-contract.sol";
import "../src/W3/D5/TokenV3.sol";

contract BankAutomationTest is Test {
    TokenV3 public token;
    TokenBankV4 public bankV4;
    BankAutomation public automation;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant THRESHOLD = 1000 * 10**18; // 1000 tokens
    uint256 constant CHECK_INTERVAL = 300; // 5 minutes
    uint256 constant MIN_TRANSFER_INTERVAL = 3600; // 1 hour
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署合约
        token = new TokenV3("TestToken", "TT");
        bankV4 = new TokenBankV4(token, THRESHOLD);
        automation = new BankAutomation(
            address(bankV4),
            CHECK_INTERVAL,
            MIN_TRANSFER_INTERVAL
        );
        
        // 设置自动化合约
        bankV4.setAutomationContract(address(automation));
        
        // 给用户分发代币
        token.mint(user1, 2000 * 10**18);
        token.mint(user2, 2000 * 10**18);
    }
    
    function testBasicDeposit() public {
        vm.startPrank(user1);
        
        uint256 depositAmount = 500 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        
        assertEq(bankV4.balances(user1), depositAmount);
        assertEq(bankV4.totalDeposit(), depositAmount);
        
        vm.stopPrank();
    }
    
    function testAutomationCheck() public {
        // 存款低于阈值时不需要转移
        vm.startPrank(user1);
        uint256 depositAmount = 500 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        vm.stopPrank();
        
        (bool needsTransfer, uint256 transferAmount) = automation.manualCheck();
        assertFalse(needsTransfer);
        assertEq(transferAmount, 0);
        
        // 存款超过阈值时需要转移
        vm.startPrank(user2);
        uint256 depositAmount2 = 600 * 10**18;
        token.approve(address(bankV4), depositAmount2);
        bankV4.deposit(depositAmount2);
        vm.stopPrank();
        
        (needsTransfer, transferAmount) = automation.manualCheck();
        assertTrue(needsTransfer);
        assertEq(transferAmount, (depositAmount + depositAmount2) / 2);
    }
    
    function testAutomationExecution() public {
        // 存款超过阈值
        vm.startPrank(user1);
        uint256 depositAmount = 1200 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        vm.stopPrank();
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 bankBalanceBefore = bankV4.totalDeposit();
        
        // 模拟 Chainlink Automation 调用
        vm.warp(block.timestamp + CHECK_INTERVAL + MIN_TRANSFER_INTERVAL);
        
        (bool upkeepNeeded,) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 执行自动转移
        automation.performUpkeep("");
        
        uint256 expectedTransfer = bankBalanceBefore / 2;
        assertEq(token.balanceOf(owner), ownerBalanceBefore + expectedTransfer);
        assertEq(bankV4.totalDeposit(), bankBalanceBefore - expectedTransfer);
    }
    
    function testManualTransfer() public {
        // 存款超过阈值
        vm.startPrank(user1);
        uint256 depositAmount = 1200 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        vm.stopPrank();
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 bankBalanceBefore = bankV4.totalDeposit();
        
        // Owner 手动执行转移
        bankV4.manualTransfer();
        
        uint256 expectedTransfer = bankBalanceBefore / 2;
        assertEq(token.balanceOf(owner), ownerBalanceBefore + expectedTransfer);
        assertEq(bankV4.totalDeposit(), bankBalanceBefore - expectedTransfer);
    }
    
    function testUpdateThreshold() public {
        uint256 newThreshold = 2000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit TokenBankV4.AutoTransferThresholdUpdated(THRESHOLD, newThreshold);
        
        bankV4.updateAutoTransferThreshold(newThreshold);
        assertEq(bankV4.autoTransferThreshold(), newThreshold);
    }
    
    function testToggleAutoTransfer() public {
        assertTrue(bankV4.autoTransferEnabled());
        
        vm.expectEmit(true, false, false, true);
        emit TokenBankV4.AutoTransferToggled(false);
        
        bankV4.toggleAutoTransfer(false);
        assertFalse(bankV4.autoTransferEnabled());
        
        // 禁用后不应该触发转移
        vm.startPrank(user1);
        uint256 depositAmount = 1200 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        vm.stopPrank();
        
        (bool needsTransfer,) = automation.manualCheck();
        assertFalse(needsTransfer);
    }
    
    function testGetBankStatus() public {
        // 存款一些代币
        vm.startPrank(user1);
        uint256 depositAmount = 800 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        vm.stopPrank();
        
        (
            uint256 totalDeposit,
            uint256 threshold,
            bool enabled,
            bool needsTransfer,
            uint256 transferAmount
        ) = automation.getBankStatus();
        
        assertEq(totalDeposit, depositAmount);
        assertEq(threshold, THRESHOLD);
        assertTrue(enabled);
        assertFalse(needsTransfer); // 还没达到阈值
        assertEq(transferAmount, 0);
    }
    
    function testGetAutomationStatus() public {
        (
            uint256 lastCheck,
            uint256 lastTransfer,
            uint256 nextCheckTime,
            uint256 nextTransferTime
        ) = automation.getAutomationStatus();
        
        assertTrue(lastCheck > 0);
        assertTrue(lastTransfer > 0);
        assertEq(nextCheckTime, lastCheck + CHECK_INTERVAL);
        assertEq(nextTransferTime, lastTransfer + MIN_TRANSFER_INTERVAL);
    }
    
    function testOnlyAutomationCanExecute() public {
        vm.startPrank(user1);
        uint256 depositAmount = 1200 * 10**18;
        token.approve(address(bankV4), depositAmount);
        bankV4.deposit(depositAmount);
        
        // 非自动化合约不能调用 executeAutoTransfer
        vm.expectRevert(TokenBankV4.OnlyAutomationContract.selector);
        bankV4.executeAutoTransfer();
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        // 非 owner 不能设置自动化合约
        vm.expectRevert(TokenBankV4.OnlyOwner.selector);
        bankV4.setAutomationContract(address(123));
        
        // 非 owner 不能更新阈值
        vm.expectRevert(TokenBankV4.OnlyOwner.selector);
        bankV4.updateAutoTransferThreshold(2000 * 10**18);
        
        // 非 owner 不能切换自动转移
        vm.expectRevert(TokenBankV4.OnlyOwner.selector);
        bankV4.toggleAutoTransfer(false);
        
        // 非 owner 不能手动转移
        vm.expectRevert(TokenBankV4.OnlyOwner.selector);
        bankV4.manualTransfer();
        
        vm.stopPrank();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/W6/D1/rebaseToken/RebaseToken.sol";

/**
 * @title RebaseTokenTest
 * @dev RebaseToken测试合约
 * @author dreamworks.cnn@gmail.com
 */
contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿枚
    uint256 public constant ANNUAL_DEFLATION_RATE = 100; // 1%

    event Rebase(
        uint256 indexed timestamp,
        uint256 oldIndex,
        uint256 newIndex,
        uint256 oldSupply,
        uint256 newSupply
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // 部署合约
        rebaseToken = new RebaseToken("Rebase Token", "RBT");
    }

    // ========== 初始化测试 ==========
    
    function testInitialState() public {
        // 测试初始状态
        assertEq(rebaseToken.name(), "Rebase Token");
        assertEq(rebaseToken.symbol(), "RBT");
        assertEq(rebaseToken.decimals(), 18);
        assertEq(rebaseToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(rebaseToken.getRebaseIndex(), 1e18);
        assertEq(rebaseToken.getAnnualDeflation(), ANNUAL_DEFLATION_RATE);
        assertEq(rebaseToken.balanceOf(owner), INITIAL_SUPPLY);
    }

    // ========== Rebase功能测试 ==========

    function testRebaseAfterOneDay() public {
        // 模拟一天后执行rebase
        vm.warp(block.timestamp + 1 days);
        
        uint256 oldIndex = rebaseToken.getRebaseIndex();
        uint256 oldSupply = rebaseToken.totalSupply();
        
        // 执行rebase
        rebaseToken.rebase();
        
        uint256 newIndex = rebaseToken.getRebaseIndex();
        uint256 newSupply = rebaseToken.totalSupply();
        
        // 验证rebase指数减少1%
        assertEq(newIndex, oldIndex * 99 / 100);
        
        // 验证总供应量减少1%
        assertEq(newSupply, oldSupply * 99 / 100);
        
        // 验证用户余额比例保持不变
        assertEq(rebaseToken.balanceOf(owner), newSupply);
    }

    function testRebaseBeforeInterval() public {
        // 尝试在间隔内执行rebase，应该失败
        vm.warp(block.timestamp + 12 hours);
        
        vm.expectRevert("RebaseToken: Rebase interval not met");
        rebaseToken.rebase();
    }

    function testMultipleRebases() public {
        // 测试多次rebase
        for (uint i = 1; i <= 5; i++) {
            vm.warp(block.timestamp + 1 days);
            rebaseToken.rebase();
            
            // 验证每次rebase后指数都减少1%
            uint256 expectedIndex = 1e18 * (99 ** i) / (100 ** i);
            assertEq(rebaseToken.getRebaseIndex(), expectedIndex);
        }
    }

    // ========== 余额计算测试 ==========

    function testBalanceCalculation() public {
        // 转账给用户1
        uint256 transferAmount = 10_000_000 * 10**18; // 1000万枚
        rebaseToken.transfer(user1, transferAmount);
        
        assertEq(rebaseToken.balanceOf(user1), transferAmount);
        
        // 执行rebase
        vm.warp(block.timestamp + 1 days);
        rebaseToken.rebase();
        
        // 验证用户余额减少1%
        assertEq(rebaseToken.balanceOf(user1), transferAmount * 99 / 100);
        assertEq(rebaseToken.balanceOf(owner), rebaseToken.totalSupply() - rebaseToken.balanceOf(user1));
    }

    function testBalanceProportionMaintained() public {
        // 分配Token给多个用户
        uint256 amount1 = 20_000_000 * 10**18; // 2000万枚
        uint256 amount2 = 30_000_000 * 10**18; // 3000万枚
        
        rebaseToken.transfer(user1, amount1);
        rebaseToken.transfer(user2, amount2);
        
        uint256 totalBefore = rebaseToken.totalSupply();
        uint256 user1Ratio = rebaseToken.balanceOf(user1) * 1e18 / totalBefore;
        uint256 user2Ratio = rebaseToken.balanceOf(user2) * 1e18 / totalBefore;
        
        // 执行rebase
        vm.warp(block.timestamp + 1 days);
        rebaseToken.rebase();
        
        uint256 totalAfter = rebaseToken.totalSupply();
        uint256 user1RatioAfter = rebaseToken.balanceOf(user1) * 1e18 / totalAfter;
        uint256 user2RatioAfter = rebaseToken.balanceOf(user2) * 1e18 / totalAfter;
        
        // 验证比例保持不变
        assertEq(user1Ratio, user1RatioAfter);
        assertEq(user2Ratio, user2RatioAfter);
    }

    // ========== 转账功能测试 ==========

    function testTransfer() public {
        uint256 transferAmount = 5_000_000 * 10**18; // 500万枚
        rebaseToken.transfer(user1, transferAmount);
        
        assertEq(rebaseToken.balanceOf(user1), transferAmount);
        assertEq(rebaseToken.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }

    function testTransferAfterRebase() public {
        // 先转账
        uint256 transferAmount = 5_000_000 * 10**18;
        rebaseToken.transfer(user1, transferAmount);
        
        // 执行rebase
        vm.warp(block.timestamp + 1 days);
        rebaseToken.rebase();
        
        // 再次转账
        uint256 newTransferAmount = 1_000_000 * 10**18;
        rebaseToken.transfer(user2, newTransferAmount);
        
        assertEq(rebaseToken.balanceOf(user2), newTransferAmount);
    }

    function testTransferInsufficientBalance() public {
        uint256 tooMuch = INITIAL_SUPPLY + 1;
        vm.expectRevert("RebaseToken: Insufficient balance");
        rebaseToken.transfer(user1, tooMuch);
    }

    function testTransferToZeroAddress() public {
        vm.expectRevert("RebaseToken: Transfer to zero address");
        rebaseToken.transfer(address(0), 1000);
    }

    // ========== 授权功能测试 ==========

    function testApproveAndTransferFrom() public {
        uint256 approveAmount = 10_000_000 * 10**18;
        rebaseToken.approve(user1, approveAmount);
        
        assertEq(rebaseToken.allowance(owner, user1), approveAmount);
        
        // 用户1使用授权转账
        vm.prank(user1);
        rebaseToken.transferFrom(owner, user2, approveAmount);
        
        assertEq(rebaseToken.balanceOf(user2), approveAmount);
        assertEq(rebaseToken.allowance(owner, user1), 0);
    }

    function testIncreaseAllowance() public {
        uint256 initialAmount = 1000;
        uint256 increaseAmount = 2000;
        
        rebaseToken.approve(user1, initialAmount);
        rebaseToken.increaseAllowance(user1, increaseAmount);
        
        assertEq(rebaseToken.allowance(owner, user1), initialAmount + increaseAmount);
    }

    function testDecreaseAllowance() public {
        uint256 initialAmount = 3000;
        uint256 decreaseAmount = 1000;
        
        rebaseToken.approve(user1, initialAmount);
        rebaseToken.decreaseAllowance(user1, decreaseAmount);
        
        assertEq(rebaseToken.allowance(owner, user1), initialAmount - decreaseAmount);
    }

    // ========== 管理功能测试 ==========

    function testSetAnnualDeflation() public {
        uint256 newRate = 200; // 2%
        rebaseToken.setAnnualDeflation(newRate);
        
        assertEq(rebaseToken.getAnnualDeflation(), newRate);
    }

    function testSetAnnualDeflationTooHigh() public {
        uint256 tooHighRate = 1500; // 15%
        vm.expectRevert("RebaseToken: Deflation rate too high");
        rebaseToken.setAnnualDeflation(tooHighRate);
    }

    function testSetAnnualDeflationNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.setAnnualDeflation(200);
    }

    // ========== 事件测试 ==========

    function testRebaseEvent() public {
        vm.warp(block.timestamp + 1 days);
        
        uint256 oldIndex = rebaseToken.getRebaseIndex();
        uint256 oldSupply = rebaseToken.totalSupply();
        
        vm.expectEmit(true, false, false, true);
        emit Rebase(block.timestamp, oldIndex, oldIndex * 99 / 100, oldSupply, oldSupply * 99 / 100);
        
        rebaseToken.rebase();
    }

    // ========== 边界条件测试 ==========

    function testRebaseWithZeroBalance() public {
        // 转账所有余额给用户1
        rebaseToken.transfer(user1, rebaseToken.balanceOf(owner));
        
        vm.warp(block.timestamp + 1 days);
        rebaseToken.rebase();
        
        // 验证用户1的余额正确减少
        assertEq(rebaseToken.balanceOf(owner), 0);
        assertEq(rebaseToken.balanceOf(user1), rebaseToken.totalSupply());
    }

    function testLongTermRebase() public {
        // 模拟长期rebase（10年）
        for (uint i = 1; i <= 10; i++) {
            vm.warp(block.timestamp + 365 days);
            rebaseToken.rebase();
        }
        
        // 验证10年后的总供应量约为初始的90.44%
        uint256 expectedSupply = INITIAL_SUPPLY * (99 ** 10) / (100 ** 10);
        assertApproxEqRel(rebaseToken.totalSupply(), expectedSupply, 0.01e18); // 1%误差
    }

    // ========== 合约信息测试 ==========

    function testGetContractInfo() public {
        (
            uint256 totalSupply_,
            uint256 rebaseIndex_,
            uint256 lastRebaseTime_,
            uint256 annualDeflation_,
            uint256 actualTotalSupply
        ) = rebaseToken.getContractInfo();
        
        assertEq(totalSupply_, INITIAL_SUPPLY);
        assertEq(rebaseIndex_, 1e18);
        assertEq(lastRebaseTime_, block.timestamp);
        assertEq(annualDeflation_, ANNUAL_DEFLATION_RATE);
        assertEq(actualTotalSupply, INITIAL_SUPPLY);
    }

    // ========== 辅助函数 ==========

    function testRebaseIndexCalculation() public {
        // 手动计算rebase指数变化
        uint256 initialIndex = 1e18;
        uint256 deflationRate = 100; // 1%
        
        // 第一次rebase
        uint256 newIndex1 = initialIndex * (10000 - deflationRate) / 10000;
        assertEq(newIndex1, initialIndex * 99 / 100);
        
        // 第二次rebase
        uint256 newIndex2 = newIndex1 * (10000 - deflationRate) / 10000;
        assertEq(newIndex2, initialIndex * 99 * 99 / (100 * 100));
    }
} 
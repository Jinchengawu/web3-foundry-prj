// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./Oracle.sol";

contract OracleTest is Test {
    Oracle public oracle;
    address public owner;
    address public updater;
    address public user;
    
    // 测试价格数据
    uint256 public constant INITIAL_PRICE = 1000000000000000000; // 1 ETH
    uint256 public constant PRICE_1 = 1200000000000000000; // 1.2 ETH
    uint256 public constant PRICE_2 = 800000000000000000;  // 0.8 ETH
    uint256 public constant PRICE_3 = 1500000000000000000; // 1.5 ETH
    uint256 public constant PRICE_4 = 900000000000000000;  // 0.9 ETH
    
    function setUp() public {
        owner = address(this);
        updater = makeAddr("updater");
        user = makeAddr("user");
        
        oracle = new Oracle();
        oracle.addAuthorizedUpdater(updater);
    }
    
    // 基础功能测试
    
    function testInitialState() public {
        assertEq(oracle.owner(), owner);
        assertTrue(oracle.authorizedUpdaters(owner));
        assertTrue(oracle.authorizedUpdaters(updater));
        assertFalse(oracle.paused());
        
        Oracle.PricePoint memory pricePoint = oracle.getLatestPricePoint();
        assertEq(pricePoint.price, 0);
        assertEq(pricePoint.cumulativePrice, 0);
        assertEq(pricePoint.cumulativeTime, 0);
    }
    
    function testUpdatePrice() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        assertEq(oracle.getLatestPrice(), INITIAL_PRICE);
        
        Oracle.PricePoint memory pricePoint = oracle.getLatestPricePoint();
        assertEq(pricePoint.price, INITIAL_PRICE);
        assertGt(pricePoint.timestamp, 0);
    }
    
    function testUpdatePriceByOwner() public {
        oracle.updatePrice(INITIAL_PRICE);
        assertEq(oracle.getLatestPrice(), INITIAL_PRICE);
    }
    
    function testUpdatePriceUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("Oracle: caller is not authorized");
        oracle.updatePrice(INITIAL_PRICE);
    }
    
    function testUpdatePriceZero() public {
        vm.prank(updater);
        vm.expectRevert("Oracle: price must be greater than 0");
        oracle.updatePrice(0);
    }
    
    // TWAP 计算测试
    
    function testGetTWAPWithSinglePrice() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        uint256 twap = oracle.getTWAP(3600); // 1小时
        assertEq(twap, INITIAL_PRICE);
    }
    
    function testGetTWAPWithMultiplePrices() public {
        // 模拟时间流逝和价格更新
        uint256 startTime = block.timestamp;
        
        // 初始价格
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 1小时后更新价格
        vm.warp(startTime + 3600);
        vm.prank(updater);
        oracle.updatePrice(PRICE_1);
        
        // 再1小时后更新价格
        vm.warp(startTime + 7200);
        vm.prank(updater);
        oracle.updatePrice(PRICE_2);
        
        // 计算2小时窗口的TWAP
        uint256 twap = oracle.getTWAP(7200);
        
        // 预期TWAP = (1 * 3600 + 1.2 * 3600) / 7200 = 1.1 ETH
        uint256 expectedTWAP = 1100000000000000000; // 1.1 ETH
        assertEq(twap, expectedTWAP);
    }
    
    function testGetDefaultTWAP() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        uint256 twap = oracle.getDefaultTWAP();
        assertEq(twap, INITIAL_PRICE);
    }
    
    function testGetTWAPInsufficientData() public {
        vm.expectRevert("Oracle: no price data available");
        oracle.getTWAP(3600);
    }
    
    function testGetTWAPInvalidWindow() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        vm.expectRevert("Oracle: window must be greater than 0");
        oracle.getTWAP(0);
    }
    
    // 价格变化限制测试
    
    function testPriceChangeLimit() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 尝试更新超过50%的价格变化
        uint256 highPrice = INITIAL_PRICE * 2; // 100% 增加
        vm.prank(updater);
        vm.expectRevert("Oracle: price change too large");
        oracle.updatePrice(highPrice);
    }
    
    function testPriceChangeWithinLimit() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 更新在限制范围内的价格
        uint256 validPrice = INITIAL_PRICE * 15 / 10; // 50% 增加
        vm.prank(updater);
        oracle.updatePrice(validPrice);
        
        assertEq(oracle.getLatestPrice(), validPrice);
    }
    
    // 模拟不同时间的交易测试
    
    function testSimulateTradingScenario() public {
        uint256 startTime = block.timestamp;
        
        // 场景：模拟一个完整的交易周期
        
        // 初始价格设置
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 30分钟后价格上涨
        vm.warp(startTime + 1800);
        vm.prank(updater);
        oracle.updatePrice(PRICE_1);
        
        // 1小时后价格下跌
        vm.warp(startTime + 5400);
        vm.prank(updater);
        oracle.updatePrice(PRICE_2);
        
        // 2小时后价格再次上涨
        vm.warp(startTime + 9000);
        vm.prank(updater);
        oracle.updatePrice(PRICE_3);
        
        // 3小时后价格稳定
        vm.warp(startTime + 12600);
        vm.prank(updater);
        oracle.updatePrice(PRICE_4);
        
        // 测试不同时间窗口的TWAP
        uint256 twap1h = oracle.getTWAP(3600);
        uint256 twap2h = oracle.getTWAP(7200);
        uint256 twap3h = oracle.getTWAP(10800);
        
        // 验证TWAP计算
        assertGt(twap1h, 0);
        assertGt(twap2h, 0);
        assertGt(twap3h, 0);
    }
    
    function testVolatilePriceScenario() public {
        uint256 startTime = block.timestamp;
        
        // 初始价格
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 模拟剧烈波动：每10分钟更新一次价格
        for (uint256 i = 1; i <= 6; i++) {
            vm.warp(startTime + i * 600); // 每10分钟
            
            uint256 newPrice = INITIAL_PRICE + (i * 100000000000000000); // 递增价格
            vm.prank(updater);
            oracle.updatePrice(newPrice);
        }
        
        // 测试短期和长期TWAP
        uint256 shortTWAP = oracle.getTWAP(1800); // 30分钟
        uint256 longTWAP = oracle.getTWAP(3600);  // 1小时
        
        assertGt(shortTWAP, 0);
        assertGt(longTWAP, 0);
    }
    
    function testNoTradingScenario() public {
        uint256 startTime = block.timestamp;
        
        // 设置初始价格
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 模拟长时间无交易（24小时）
        vm.warp(startTime + 86400);
        
        // 获取TWAP，应该返回最新价格
        uint256 twap = oracle.getTWAP(3600);
        assertEq(twap, INITIAL_PRICE);
        
        // 24小时后更新价格
        vm.prank(updater);
        oracle.updatePrice(PRICE_1);
        
        twap = oracle.getTWAP(3600);
        assertEq(twap, PRICE_1);
    }
    
    // 管理功能测试
    
    function testAddRemoveAuthorizedUpdater() public {
        address newUpdater = makeAddr("newUpdater");
        
        oracle.addAuthorizedUpdater(newUpdater);
        assertTrue(oracle.authorizedUpdaters(newUpdater));
        
        vm.prank(newUpdater);
        oracle.updatePrice(INITIAL_PRICE);
        assertEq(oracle.getLatestPrice(), INITIAL_PRICE);
        
        oracle.removeAuthorizedUpdater(newUpdater);
        assertFalse(oracle.authorizedUpdaters(newUpdater));
        
        vm.prank(newUpdater);
        vm.expectRevert("Oracle: caller is not authorized");
        oracle.updatePrice(PRICE_1);
    }
    
    function testPauseUnpause() public {
        oracle.pause();
        assertTrue(oracle.paused());
        
        vm.prank(updater);
        vm.expectRevert("Oracle: paused");
        oracle.updatePrice(INITIAL_PRICE);
        
        oracle.unpause();
        assertFalse(oracle.paused());
        
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        assertEq(oracle.getLatestPrice(), INITIAL_PRICE);
    }
    
    function testEmergencyUpdatePrice() public {
        oracle.emergencyUpdatePrice(INITIAL_PRICE);
        assertEq(oracle.getLatestPrice(), INITIAL_PRICE);
        
        // 测试紧急更新可以超过价格变化限制
        uint256 emergencyPrice = INITIAL_PRICE * 3; // 200% 增加
        oracle.emergencyUpdatePrice(emergencyPrice);
        assertEq(oracle.getLatestPrice(), emergencyPrice);
    }
    
    function testTransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        
        oracle.transferOwnership(newOwner);
        assertEq(oracle.owner(), newOwner);
        
        // 原所有者应该失去权限
        vm.expectRevert("Oracle: caller is not the owner");
        oracle.pause();
        
        // 新所有者应该有权限
        vm.prank(newOwner);
        oracle.pause();
        assertTrue(oracle.paused());
    }
    
    // 边界条件测试
    
    function testConsecutivePriceUpdates() public {
        // 测试连续快速更新价格
        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(updater);
            oracle.updatePrice(INITIAL_PRICE + i * 10000000000000000);
            
            // 每次更新后验证价格
            assertEq(oracle.getLatestPrice(), INITIAL_PRICE + i * 10000000000000000);
        }
    }
    
    function testLargeTimeGap() public {
        vm.prank(updater);
        oracle.updatePrice(INITIAL_PRICE);
        
        // 模拟非常大的时间间隔
        vm.warp(block.timestamp + 365 days);
        
        vm.prank(updater);
        oracle.updatePrice(PRICE_1);
        
        // 应该仍然能正常工作
        assertEq(oracle.getLatestPrice(), PRICE_1);
    }
    
    // 事件测试
    
    function testEvents() public {
        vm.prank(updater);
        vm.expectEmit(true, true, false, true);
        emit Oracle.PriceUpdated(block.timestamp, INITIAL_PRICE, 0);
        oracle.updatePrice(INITIAL_PRICE);
    }
} 
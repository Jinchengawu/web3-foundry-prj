// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Delegate} from "../src/W4/D5/Delegate.sol";
import {TokenV3} from "../src/W3/D5/TokenV3.sol";
import {TokenBank} from "../src/W2/D2/TokenBank.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 测试用的简单合约
contract MockContract {
    uint256 public value;
    address public lastCaller;
    
    function setValue(uint256 _value) external payable {
        value = _value;
        lastCaller = msg.sender;
    }
    
    function getValue() external view returns (uint256) {
        return value;
    }
    
    function revertFunction() external pure {
        revert("Test revert");
    }
    
    // 用于测试 delegatecall
    function setValueDelegate(uint256 _value) external {
        value = _value;
    }
    
    // 让合约能接收 ETH
    receive() external payable {}
}

// 测试用的 TokenBank 合约
contract MockTokenBank {
    IERC20 public token;
    mapping(address => uint256) public balances;
    uint256 public totalDeposit;
    
    constructor(IERC20 _token) {
        token = _token;
    }
    
    function deposit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        totalDeposit += amount;
    }
    
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalDeposit -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
}

contract DelegateTest is Test {
    Delegate public delegate;
    TokenV3 public token;
    MockTokenBank public tokenBank;
    MockContract public mockContract;
    
    // 测试账户
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public unauthorized = address(0x4);
    
    // 事件声明
    event BatchExecuted(address indexed caller, uint256 callCount);
    event DelegateCallExecuted(address indexed caller, address indexed target, bool success);
    event TokenApproved(address indexed token, address indexed spender, uint256 amount);
    event TokenDeposited(address indexed bank, address indexed token, uint256 amount);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);
    event PausedStateChanged(bool paused);
    
    function setUp() public {
        // 部署合约
        vm.prank(owner);
        delegate = new Delegate(owner);
        
        token = new TokenV3("TestToken", "TT");
        tokenBank = new MockTokenBank(IERC20(address(token)));
        mockContract = new MockContract();
        
        // 给测试账户发放代币
        token.mint(alice, 1000e18);
        token.mint(bob, 1000e18);
        token.mint(address(delegate), 1000e18);
        
        // 给合约发送一些 ETH
        vm.deal(address(delegate), 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }
    
    // === 基础功能测试 ===
    
    function test_Constructor() public {
        // 测试构造函数
        assertEq(delegate.owner(), owner);
        assertFalse(delegate.paused());
    }
    
    function test_ConstructorZeroAddress() public {
        // 测试零地址构造函数应该失败
        // OpenZeppelin 的 Ownable 会先检查 _owner != address(0)
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new Delegate(address(0));
    }
    
    // === 权限管理测试 ===
    
    function test_AddAuthorizedCaller() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AuthorizedCallerAdded(alice);
        delegate.addAuthorizedCaller(alice);
        
        assertTrue(delegate.authorizedCallers(alice));
    }
    
    function test_AddAuthorizedCallerZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Delegate.ZeroAddress.selector);
        delegate.addAuthorizedCaller(address(0));
    }
    
    function test_AddAuthorizedCallerNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        delegate.addAuthorizedCaller(bob);
    }
    
    function test_RemoveAuthorizedCaller() public {
        // 先添加授权
        vm.prank(owner);
        delegate.addAuthorizedCaller(alice);
        
        // 然后移除
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AuthorizedCallerRemoved(alice);
        delegate.removeAuthorizedCaller(alice);
        
        assertFalse(delegate.authorizedCallers(alice));
    }
    
    function test_SetPaused() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit PausedStateChanged(true);
        delegate.setPaused(true);
        
        assertTrue(delegate.paused());
    }
    
    // === 批量执行功能测试 ===
    
    function test_Multicall() public {
        Delegate.Call[] memory calls = new Delegate.Call[](2);
        
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValue(uint256)", 42)
        });
        
        calls[1] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValue(uint256)", 84)
        });
        
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchExecuted(alice, 2);
        bytes[] memory results = delegate.multicall(calls);
        
        assertEq(results.length, 2);
        assertEq(mockContract.value(), 84); // 最后一次调用的值
    }
    
    function test_MulticallFailed() public {
        Delegate.Call[] memory calls = new Delegate.Call[](1);
        
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("revertFunction()")
        });
        
        vm.prank(alice);
        vm.expectRevert();
        delegate.multicall(calls);
    }
    
    function test_MulticallWhenPaused() public {
        // 暂停合约
        vm.prank(owner);
        delegate.setPaused(true);
        
        Delegate.Call[] memory calls = new Delegate.Call[](1);
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValue(uint256)", 42)
        });
        
        vm.prank(alice);
        vm.expectRevert(Delegate.ContractPaused.selector);
        delegate.multicall(calls);
    }
    
    function test_MulticallWithValue() public {
        Delegate.CallWithValue[] memory calls = new Delegate.CallWithValue[](1);
        
        calls[0] = Delegate.CallWithValue({
            target: address(mockContract),
            value: 1 ether,
            callData: abi.encodeWithSignature("setValue(uint256)", 42)
        });
        
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchExecuted(alice, 1);
        bytes[] memory results = delegate.multicallWithValue{value: 1 ether}(calls);
        
        assertEq(results.length, 1);
        assertEq(mockContract.value(), 42);
        assertEq(address(mockContract).balance, 1 ether);
    }
    
    function test_MulticallWithValueInsufficientETH() public {
        Delegate.CallWithValue[] memory calls = new Delegate.CallWithValue[](1);
        
        calls[0] = Delegate.CallWithValue({
            target: address(mockContract),
            value: 2 ether,
            callData: abi.encodeWithSignature("setValue(uint256)", 42)
        });
        
        vm.prank(alice);
        vm.expectRevert(Delegate.InsufficientBalance.selector);
        delegate.multicallWithValue{value: 1 ether}(calls);
    }
    
    function test_MulticallDelegate() public {
        // 先授权 alice
        vm.prank(owner);
        delegate.addAuthorizedCaller(alice);
        
        Delegate.Call[] memory calls = new Delegate.Call[](1);
        
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValueDelegate(uint256)", 42)
        });
        
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit DelegateCallExecuted(alice, address(mockContract), true);
        bytes[] memory results = delegate.multicallDelegate(calls);
        
        assertEq(results.length, 1);
        // delegatecall 会修改 delegate 合约的状态，而不是 mockContract 的状态
    }
    
    function test_MulticallDelegateUnauthorized() public {
        Delegate.Call[] memory calls = new Delegate.Call[](1);
        
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValueDelegate(uint256)", 42)
        });
        
        vm.prank(alice);
        vm.expectRevert(Delegate.UnauthorizedCaller.selector);
        delegate.multicallDelegate(calls);
    }
    
    // === TokenBank 交互功能测试 ===
    
    function test_ApproveAndDeposit() public {
        uint256 amount = 100e18;
        
        // Alice 先授权给 delegate 合约
        vm.prank(alice);
        token.approve(address(delegate), amount);
        
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit TokenApproved(address(token), address(tokenBank), amount);
        vm.expectEmit(true, true, false, true);
        emit TokenDeposited(address(tokenBank), address(token), amount);
        delegate.approveAndDeposit(address(token), address(tokenBank), amount);
        
        // 验证存款成功
        assertEq(tokenBank.balances(address(delegate)), amount);
        assertEq(token.balanceOf(alice), 1000e18 - amount);
    }
    
    function test_ApproveAndDepositZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(Delegate.ZeroAddress.selector);
        delegate.approveAndDeposit(address(0), address(tokenBank), 100e18);
        
        vm.prank(alice);
        vm.expectRevert(Delegate.ZeroAddress.selector);
        delegate.approveAndDeposit(address(token), address(0), 100e18);
    }
    
    function test_BatchApproveAndDeposit() public {
        address[] memory tokens = new address[](2);
        address[] memory tokenBanks = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        
        tokens[0] = address(token);
        tokens[1] = address(token);
        tokenBanks[0] = address(tokenBank);
        tokenBanks[1] = address(tokenBank);
        amounts[0] = 50e18;
        amounts[1] = 50e18;
        
        // Alice 先授权给 delegate 合约
        vm.prank(alice);
        token.approve(address(delegate), 100e18);
        
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchExecuted(alice, 2);
        delegate.batchApproveAndDeposit(tokens, tokenBanks, amounts);
        
        // 验证存款成功
        assertEq(tokenBank.balances(address(delegate)), 100e18);
        assertEq(token.balanceOf(alice), 900e18);
    }
    
    function test_BatchApproveAndDepositArrayLengthMismatch() public {
        address[] memory tokens = new address[](2);
        address[] memory tokenBanks = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        
        vm.prank(alice);
        vm.expectRevert(Delegate.ArrayLengthMismatch.selector);
        delegate.batchApproveAndDeposit(tokens, tokenBanks, amounts);
    }
    
    // === 代理调用功能测试 ===
    
    function test_DelegateCall() public {
        // 先授权 alice
        vm.prank(owner);
        delegate.addAuthorizedCaller(alice);
        
        bytes memory data = abi.encodeWithSignature("setValueDelegate(uint256)", 42);
        
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit DelegateCallExecuted(alice, address(mockContract), true);
        (bool success, bytes memory returnData) = delegate.delegateCall(address(mockContract), data);
        
        assertTrue(success);
    }
    
    function test_DelegateCallUnauthorized() public {
        bytes memory data = abi.encodeWithSignature("setValueDelegate(uint256)", 42);
        
        vm.prank(alice);
        vm.expectRevert(Delegate.UnauthorizedCaller.selector);
        delegate.delegateCall(address(mockContract), data);
    }
    
    // === 紧急功能测试 ===
    
    function test_EmergencyWithdraw() public {
        uint256 amount = 100e18;
        
        vm.prank(owner);
        delegate.emergencyWithdraw(address(token), owner, amount);
        
        assertEq(token.balanceOf(owner), amount);
        assertEq(token.balanceOf(address(delegate)), 1000e18 - amount);
    }
    
    function test_EmergencyWithdrawZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Delegate.ZeroAddress.selector);
        delegate.emergencyWithdraw(address(token), address(0), 100e18);
    }
    
    function test_EmergencyWithdrawNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        delegate.emergencyWithdraw(address(token), alice, 100e18);
    }
    
    function test_EmergencyWithdrawETH() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = address(this).balance; // 使用测试合约作为接收者
        
        vm.prank(owner);
        delegate.emergencyWithdrawETH(payable(address(this)), amount);
        
        assertEq(address(this).balance, initialBalance + amount);
        assertEq(address(delegate).balance, 10 ether - amount);
    }
    
    // 添加 receive 函数让测试合约能接收 ETH
    receive() external payable {}
    
    function test_EmergencyWithdrawETHZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Delegate.ZeroAddress.selector);
        delegate.emergencyWithdrawETH(payable(address(0)), 1 ether);
    }
    
    // === 工具函数测试 ===
    
    function test_GetAllowance() public {
        uint256 amount = 100e18;
        
        // 从 delegate 合约授权给 tokenBank
        vm.prank(address(delegate));
        token.approve(address(tokenBank), amount);
        
        uint256 allowance = delegate.getAllowance(address(token), address(tokenBank));
        assertEq(allowance, amount);
    }
    
    function test_GetTokenBalance() public {
        uint256 balance = delegate.getTokenBalance(address(token));
        assertEq(balance, 1000e18);
    }
    
    function test_GetETHBalance() public {
        uint256 balance = delegate.getETHBalance();
        assertEq(balance, 10 ether);
    }
    
    // === 接收 ETH 测试 ===
    
    function test_ReceiveETH() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = address(delegate).balance;
        
        vm.prank(alice);
        (bool success, ) = payable(address(delegate)).call{value: amount}("");
        assertTrue(success);
        
        assertEq(address(delegate).balance, initialBalance + amount);
    }
    
    function test_FallbackETH() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = address(delegate).balance;
        
        vm.prank(alice);
        (bool success, ) = payable(address(delegate)).call{value: amount}("0x1234");
        assertTrue(success);
        
        assertEq(address(delegate).balance, initialBalance + amount);
    }
    
    // === 综合测试场景 ===
    
    function test_CompleteWorkflow() public {
        // 1. 设置授权用户
        vm.prank(owner);
        delegate.addAuthorizedCaller(alice);
        
        // 2. Alice 授权代币给 delegate
        vm.prank(alice);
        token.approve(address(delegate), 200e18);
        
        // 3. 先单独执行存款操作
        vm.prank(alice);
        delegate.approveAndDeposit(address(token), address(tokenBank), 100e18);
        
        // 4. 使用 multicall 执行其他操作
        Delegate.Call[] memory calls = new Delegate.Call[](2);
        
        // 设置两个不同的值
        calls[0] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValue(uint256)", 999)
        });
        
        calls[1] = Delegate.Call({
            target: address(mockContract),
            callData: abi.encodeWithSignature("setValue(uint256)", 888)
        });
        
        vm.prank(alice);
        bytes[] memory results = delegate.multicall(calls);
        
        // 验证结果
        assertEq(results.length, 2);
        assertEq(tokenBank.balances(address(delegate)), 100e18);
        assertEq(mockContract.value(), 888); // 最后一次调用的值
        assertEq(token.balanceOf(alice), 900e18);
    }
}
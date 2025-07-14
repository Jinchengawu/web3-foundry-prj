// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../src/W2/D2/MyERC20.sol"; // 路径根据实际情况调整

contract MyERC20Test is Test {
    BaseERC20 public token;
    address public owner;
    address public user1;
    address public user2;
    address public randomAddr;

    uint256 public constant DECIMALS = 18;
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18; // 1亿

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        randomAddr = address(0x3);

        token = new BaseERC20();
    }

    function testName() public {
        assertEq(token.name(), "BaseERC20");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "BERC20");
    }

    function testDecimals() public {
        assertEq(token.decimals(), DECIMALS);
    }

    function testTotalSupply() public {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function testBalanceOfOwner() public {
        assertEq(token.balanceOf(owner), TOTAL_SUPPLY);
    }

    function testTransferFailNotEnoughBalance() public {
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        token.transfer(randomAddr, TOTAL_SUPPLY + 1);
    }

    function testTransferUpdatesBalances() public {
        uint256 amount = 100;
        token.transfer(user1, amount);
        assertEq(token.balanceOf(owner), TOTAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testApprove() public {
        uint256 amount = 100;
        token.approve(user1, amount);
        assertEq(token.allowance(owner, user1), amount);
    }

    function testAllowanceAfterTransferFrom() public {
        uint256 approveAmount = 10;
        uint256 usedAmount = 5;
        token.approve(user1, approveAmount);

        vm.prank(user1);
        token.transferFrom(owner, user2, usedAmount);

        assertEq(token.allowance(owner, user1), approveAmount - usedAmount);
    }

    function testTransferFrom() public {
        uint256 amount = 100;
        token.approve(user1, amount);

        vm.prank(user1);
        token.transferFrom(owner, user2, amount);

        assertEq(token.balanceOf(user2), amount);
    }

    function testTransferFromFailNotEnoughTokens() public {
        uint256 allowanceAmount = TOTAL_SUPPLY + 1;
        token.approve(user1, allowanceAmount);

        vm.prank(user1);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        token.transferFrom(owner, user2, allowanceAmount);
    }

    function testTransferFromFailMoreThanApproved() public {
        uint256 allowanceAmount = 100;
        token.approve(user1, allowanceAmount);

        vm.prank(user1);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds allowance"));
        token.transferFrom(owner, user2, allowanceAmount + 1);
    }
}
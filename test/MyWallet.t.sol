// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/W4/D3/MyWallet.sol";

contract MyWalletTest is Test {
    MyWallet public wallet;
    address public owner = address(1);
    address public newOwner = address(2);
    address public user = address(3);

    function setUp() public {
        vm.prank(owner);
        wallet = new MyWallet("Test Wallet");
    }

    function testConstructor() public {
        assertEq(wallet.owner(), owner);
        assertEq(wallet.name(), "Test Wallet");
    }

    function testTransferOwnership() public {
        vm.prank(owner);
        wallet.transferOwnership(newOwner);
        assertEq(wallet.owner(), newOwner);
    }

    function testTransferOwnershipWithAssembly() public {
        vm.prank(owner);
        wallet.transferOwnershipWithAssembly(newOwner);
        assertEq(wallet.owner(), newOwner);
    }

    function testGetOwnerWithAssembly() public {
        address currentOwner = wallet.getOwnerWithAssembly();
        assertEq(currentOwner, owner);
    }

    function testDangerousTransferOwnership() public {
        // 这个函数没有权限检查，任何人都可以调用
        vm.prank(user);
        wallet.dangerousTransferOwnership(newOwner);
        assertEq(wallet.owner(), newOwner);
    }

    function testBatchUpdateWithAssembly() public {
        vm.prank(owner);
        wallet.batchUpdateWithAssembly(newOwner, "New Name");
        assertEq(wallet.owner(), newOwner);
    }

    function testFailTransferOwnershipNotAuthorized() public {
        vm.prank(user);
        wallet.transferOwnership(newOwner);
    }

    function testFailTransferOwnershipWithAssemblyNotAuthorized() public {
        vm.prank(user);
        wallet.transferOwnershipWithAssembly(newOwner);
    }

    function testFailTransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        wallet.transferOwnership(address(0));
    }

    function testFailTransferOwnershipWithAssemblyToZeroAddress() public {
        vm.prank(owner);
        wallet.transferOwnershipWithAssembly(address(0));
    }

    function testFailDangerousTransferOwnershipToZeroAddress() public {
        vm.prank(user);
        wallet.dangerousTransferOwnership(address(0));
    }

    function testFailTransferOwnershipToSameAddress() public {
        vm.prank(owner);
        wallet.transferOwnership(owner);
    }

    function testFailTransferOwnershipWithAssemblyToSameAddress() public {
        vm.prank(owner);
        wallet.transferOwnershipWithAssembly(owner);
    }

    // 演示内联汇编的存储操作
    function testStorageSlotOperations() public {
        // 验证存储槽2确实是owner的位置
        bytes32 slot2Value;
        assembly {
            slot2Value := sload(2)
        }
        assertEq(address(uint160(uint256(slot2Value))), owner);
    }

    // 演示直接通过内联汇编修改存储
    function testDirectStorageModification() public {
        // 直接修改存储槽2
        address targetOwner = newOwner;
        assembly {
            sstore(2, targetOwner)
        }
        assertEq(wallet.owner(), newOwner);
    }
} 
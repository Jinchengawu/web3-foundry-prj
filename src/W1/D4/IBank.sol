// SPDX-License-Identifier: MIT
pragma solidity^0.8.13;

interface IBank {
    function withdraw(address _toAddress, uint256 amount) external payable;
    function deposit() external payable;
    function changeOwner(address _newOwner) external;
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Lending Market Interface
 * @dev 定义与借贷市场交互的接口
 */
interface ILendingMarket {
    /**
     * @dev 存入 ETH 到借贷市场
     * @param amount 存入数量
     */
    function deposit(uint256 amount) external payable;
    
    /**
     * @dev 从借贷市场提取 ETH
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external;
    
    /**
     * @dev 获取用户在借贷市场的余额
     * @param user 用户地址
     * @return 余额
     */
    function balanceOf(address user) external view returns (uint256);
    
    /**
     * @dev 获取借贷市场的年化收益率
     * @return 年化收益率（以 wei 为单位）
     */
    function getAPY() external view returns (uint256);
    
    /**
     * @dev 获取用户应得的利息
     * @param user 用户地址
     * @return 利息数量
     */
    function getInterest(address user) external view returns (uint256);
    
    /**
     * @dev 领取利息
     * @param user 用户地址
     */
    function claimInterest(address user) external;
} 
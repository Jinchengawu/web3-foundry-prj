// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AutomationCompatibleInterface
 * @dev 简化的Chainlink Automation兼容接口
 * 在实际部署时，应该使用官方的Chainlink合约库
 */
interface AutomationCompatibleInterface {
    /**
     * @notice 检查是否需要执行upkeep
     * @param checkData 检查数据，由注册时提供
     * @return upkeepNeeded 如果需要执行upkeep则返回true
     * @return performData 传递给performUpkeep的数据
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @notice 执行upkeep任务
     * @param performData checkUpkeep返回的数据
     */
    function performUpkeep(bytes calldata performData) external;
}
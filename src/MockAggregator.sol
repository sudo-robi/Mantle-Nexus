// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAggregator {
    int256 public answer;
    uint8 public overrideDecimals;
    uint256 public lastUpdated;

    constructor(int256 _answer, uint8 _decimals) {
        answer = _answer;
        overrideDecimals = _decimals;
        lastUpdated = block.timestamp;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
        lastUpdated = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 _answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, answer, block.timestamp, lastUpdated, 0);
    }

    function decimals() external view returns (uint8) {
        return overrideDecimals;
    }
}

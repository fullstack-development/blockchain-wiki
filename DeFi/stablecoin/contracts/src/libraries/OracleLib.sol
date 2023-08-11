// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice Эта библиотека будет проверять актуальность получаемой стоимости актива из Chainlink.
 * Это необходимо потому что priceFeeds в chainlink обновляются с некоторой периодичностью
 */
library OracleLib {
    uint256 private constant TIMEOUT = 3 hours;

    error StalePrice();

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
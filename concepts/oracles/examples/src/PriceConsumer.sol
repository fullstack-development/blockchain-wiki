// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/utils/math/SafeCast.sol";

/// @notice Контракт для получения стоимости токена, основанной на PriceFeed от Chainlink
contract PriceConsumer {
    /// @notice Подключаем прекрасную библиотеку, которая позволяет конвертировать Int в Uint
    using SafeCast for int256;

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia
     * Aggregator: BTC/USD
     * Address: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
     * @dev Пример будет работать в сети Sepolia для соответствующего контракта Aggregator
     */
    constructor(address aggregator) {
        priceFeed = AggregatorV3Interface(aggregator);
    }

    /**
     * @notice Возвращает стоимость токена Биткоин относительно USD
     */
    function getLatestPrice() public view returns (uint256) {
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        return price.toUint256();
    }
}
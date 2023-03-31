// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracle} from "./interfaces/IOracle.sol";
import {RequestType} from "./utils/Constants.sol";

/**
 * @notice Пример контракта, которому необходимо получать информацию о прайсе off-chain
 * @dev Получает off-chain данные через специальный контракт Oracle
 */
contract Client {
    /// @notice Экземпляр контракта Oracle
    IOracle private _oracle;

    /// @notice Приватная переменная для записи off-chain информации о прайсе
    uint256 private _price;

    event OracleSet(address oracle);
    event PriceSet(uint256 price);

    error OnlyOracle();

    modifier onlyOracle {
        if (msg.sender != address(_oracle)) {
            revert OnlyOracle();
        }

        _;
    }

    constructor(address oracle) {
        _oracle = IOracle(oracle);

        emit OracleSet(oracle);
    }

    /**
     * @notice Делает запрос за off-chain данными на контракт Oracle
     * @param oracleNode Адрес от имени которого oracle node может взаимодействовать с контрактом Oracle
     * Oracle node находится в off-chain пространстве
     */
    function requestPrice(address oracleNode) external {
        bytes memory data = abi.encode(RequestType.GET_PRICE);

        _oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: Client.setPrice.selector
            })
        );
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }

    /**
     * @notice Функция которая будет вызвана контрактом Oracle для обновления информации о прайсе
     * @param data Набор закодированных данных, который содержат информацию о прайсе
     */
    function setPrice(bytes memory data) external onlyOracle {
        uint256 price = abi.decode(data, (uint256));

        _price = price;

        emit PriceSet(price);
    }
}
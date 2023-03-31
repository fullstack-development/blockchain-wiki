// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {IOracle} from "./interfaces/IOracle.sol";

/**
 * @notice Пример контракта Oracle, через который другие контракты могут получать off-chain данные
 * @dev Получает on-chain запрос от контракта Client и генерирует запрос к оракл node на получение off-chain данных
 * Ожидается, что вызов функции executeRequest() будет доставлять off-chain данные до запросившего контракта
 */
contract Oracle is IOracle, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _requestIds;

    /// @notice Список запросов на получение off-chain данных
    mapping(uint256 => Request) private _requests;

    /// @notice Список адресов от имени которых oracle nodes смогут взаимодействовать с контрактом Oracle
    mapping(address => bool) private _oracleNodes;

    function getRequestById(uint256 requestId) external view returns (Request memory) {
        return _requests[requestId];
    }

    /**
     * @notice Создает запрос на получение данных и бросает событие, которое будет поймано oracle node off-chain
     * @param oracleNode Адрес от имени которого oracle node может взаимодействовать с контрактом Oracle
     * @param data Данные для запроса
     * @param callback Данные для переадресации ответа
     */
    function createRequest(address oracleNode, bytes memory data, Callback memory callback)
        external
        returns (uint256 requestId)
    {
        bool isTrusted = isOracleNodeTrusted(oracleNode);

        if (!isTrusted) {
            revert OracleNodeNotTrusted(oracleNode);
        }

        _requestIds.increment();
        requestId = _requestIds.current();

        _requests[requestId] = Request({
            oracleNode: oracleNode,
            callback: callback
        });

        emit RequestCreated(requestId, data);
    }

    /**
     * @notice Выполнение запроса на получение off-chain данных
     * @dev Только адрес установленный для соответствующего запроса сможет вызвать функцию выполнения запроса
     * @param requestId Идентификатор запроса на получение off-chain данных
     * @param data Off-chain данные
     */
    function executeRequest(uint256 requestId, bytes memory data) external {
        Request memory request = _requests[requestId];

        if (request.oracleNode == address(0)) {
            revert RequestNotFound(requestId);
        }

        if (msg.sender != request.oracleNode) {
            revert SenderShouldBeEqualOracleNodeRequest();
        }

        (bool success,) = request.callback.to
            .call(abi.encodeWithSelector(request.callback.functionSelector, data));

        if (!success) {
            revert ExecuteFailed(requestId);
        }

        emit RequestExecuted(requestId);
    }

    function isOracleNodeTrusted(address account) public view returns (bool) {
        return _oracleNodes[account];
    }

    function setOracleNode(address account) external onlyOwner {
        _oracleNodes[account] = true;

        emit OracleNodeSet(account);
    }

    function removeOracleNode(address account) external onlyOwner {
        delete _oracleNodes[account];

        emit OracleNodeRemoved(account);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @notice Смарт-контракт, который выполняет простое действие
 * @dev Этот контракт используется для демонстрации вызова функции execute через делегирование вызова из смарт-контракта Router
 */
contract ActionSimple {
    event Executed(bool success);

    /**
     * @notice Выполняет действие и генерирует событие Executed
     * @dev Эта функция вызывается через делегирование вызова из смарт-контракта Router
     */
    function execute() external {
        emit Executed(true);
    }
}
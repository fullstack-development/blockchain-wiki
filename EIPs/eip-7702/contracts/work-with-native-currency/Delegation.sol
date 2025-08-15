// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation
 * @author Pavel Naydanov
 * @notice Показываем работу c нативной валютой
 */
contract Delegation {
    /// Оставляем нативную валюту на адресе user
    function buy() external payable {}

    /// @notice Пересылаем нативную валюту на смарт-контракт target
    function buyAndSendToTarget(address target) external payable {
        (bool success, ) = target.call{value: msg.value}("");

        if (!success) {
            revert();
        }
    }
}

contract Target {
    // Разрешаем принимать нативную валюту
    receive() external payable {}
}
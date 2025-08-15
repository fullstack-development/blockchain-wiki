// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation
 * @author Pavel Naydanov
 * @notice Показываем работу хранилища и контекста вызовов при делегировании вызовов через EOA
 */
contract Delegation {
    uint256 private _value;

    constructor(uint256 initialValue) {
        _value = initialValue;
    }

    // Записываем значение в хранилище
    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    // Получаем значение из хранилища
    function getValue() external view returns (uint256) {
        return _value;
    }
}
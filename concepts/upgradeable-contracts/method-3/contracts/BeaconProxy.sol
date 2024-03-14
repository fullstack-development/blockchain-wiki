// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * Порядок деплоя для тестирования в remix:
 *      1. Деплой контракта Logic
 *      2. Деплой контракта Beacon(address Logic, address Owner)
 *      3. Деплой контракта LogicProxy(address Beacon, 0x)
 *      4. Деплой контракта LogicProxy2(address Beacon, 0x)
 *      5. Деплой нового контракта Logic2
 *      6. Вызов upgradeTo(address Logic2) на контракте Beacon
 *      7. Вызов функции getImplemetation() на каждом контракте LogicProxy для проверки смены контракта логики
 */

/// Контракт логики
contract Logic {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// Контракт логики для обновления
contract Logic2 {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function increment() public {
        _value += 1;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

// Контракт Beacon
contract Beacon is UpgradeableBeacon {
    // Для обновления логики для всех контрактов прокси нужно вызывать функцию upgradeTo() на контракте Beacon
    constructor(address _implementation, address _owner) UpgradeableBeacon(_implementation, _owner) {}
}

/// Контракт First прокси
contract LogicProxy is BeaconProxy {
    constructor(address _beacon, bytes memory _data) BeaconProxy(_beacon, _data) {}

    /// @notice Возвращает адрес Beacon контракта
    function getBeacon() public view returns (address) {
        return _getBeacon();
    }

    /// @notice Возвращает адрес установленного контракта логики для прокси
    function getImplemetation() public view returns (address) {
        return _implementation();
    }

    /// @notice Возвращает описание прокси
    function getProxyDescription() external view returns (string memory) {
        return "First proxy";
    }
}

/// Контракт Second прокси
contract LogicProxy2 is BeaconProxy {
    constructor(address _beacon, bytes memory _data) BeaconProxy(_beacon, _data) {}

    /// @notice Возвращает адрес Beacon контракта
    function getBeacon() public view returns (address) {
        return _getBeacon();
    }

    /// @notice Возвращает адрес установленного контракта логики для прокси
    function getImplemetation() public view returns (address) {
        return _implementation();
    }

    /// @notice Возвращает описание прокси
    function getProxyDescription() external view returns (string memory) {
        return "Second proxy";
    }
}

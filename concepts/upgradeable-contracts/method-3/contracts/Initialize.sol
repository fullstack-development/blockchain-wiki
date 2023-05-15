// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * Чтобы понять контракты. Лучше всего задеплоить их при помощи Remix.
 * Порядок деплоя:
 *      1. Задеплоить контрат Logic. Попробовать вызвать initialize() на задеплоенном контракте.
 *         Наша защита не позволит этого сделать
 *      2. Задеплоить контракт Admin
 *      3. Задеплоить контракт LogicProxy(address Logic, address Admin, 0x)
 *      4. Задеплоить контракт LogicProxy с ABI контракта Logic при помощи встроенного в ремикс функционала "Deploy at address"
 *         Это позволит вызывать методы контракта Logic для контракта LogicProxy
 *      5. Вызвать функцию initialize() на последнем задеплоенном контракте LogicProxy(задеплоен с ABI контракта Logic)
 *         Убедиться, что транзакция прошла успешно. Вызвать функцию initialize() повторно. Убедиться что транзакция вернулась с ошибкой
 *
 * Для обновления имплементации вызывать метод upgrade() на контракте Admin
 */

/// Контракт логики
contract Logic is Initializable {
    uint256 private _defaultValue;
    uint256 private _value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// Это не позволит инициализировать контракт логики миную прокси
        _disableInitializers();
    }

    /**
     * @notice Функция инициализации.
     * @param defaultValue Дефолтное значение
     * @dev Используется модификатор из контракта Initializable.sol от OpenZeppelin
     */
    function initialize(uint256 defaultValue) external initializer {
        _defaultValue = defaultValue;
    }

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        if (_value != 0) {
            return _value;
        }

        return _defaultValue;
    }
}

/// Контракт прокси
contract LogicProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}
}

/**
 * @notice Контракт прокси админа
 * @dev Только прокси админ может обновлять контракт логики для прокси.
 * Поэтому технически необходимо вызывать метод upgrade() у контракта админа
 */
contract Admin is ProxyAdmin {}
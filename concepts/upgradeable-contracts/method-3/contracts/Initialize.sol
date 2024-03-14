// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * Чтобы понять контракты. Лучше всего задеплоить их при помощи Remix.
 * Порядок деплоя:
 *      1. Задеплоить контрат Logic. Попробовать вызвать initialize() на задеплоенном контракте.
 *         Наша защита не позволит этого сделать
 *      2. Задеплоить контракт LogicProxy(address Logic, address InitialOwner, 0x)
 *      3. Связать ABI контракта Logic с LogicProxy при помощи встроенного в Remix функционала "Deploy at address".
 *         Чтобы сделать это необходимо выбрать в поле CONTRACT - Logic, а в "At Address" установить адрес LogicProxy. Нажать на кнопку "At address"
 *          Это позволит вызывать методы контракта Logic для контракта LogicProxy
 *      4. Вызвать функцию initialize() на контракте Logic (из пункта 3, этот контракт позволяет прокси вызывать методы Logic)
 *         Убедиться, что транзакция прошла успешно. Вызвать функцию initialize() повторно. Убедиться что транзакция вернулась с ошибкой
 *
 * Для обновления имплементации вызывать метод upgradeAndCall() на контракте ProxyAdmin
 * (адрес админа можно получить на LogicProxy вызвав getAdmin(), затем связать его с ABI ProxyAdmin как в пункте 3)
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
    constructor(address _logic, address _initialOwner, bytes memory _data)
        TransparentUpgradeableProxy(_logic, _initialOwner, _data)
    {}

    function getAdmin() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
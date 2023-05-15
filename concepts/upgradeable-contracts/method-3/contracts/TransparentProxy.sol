// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * Чтобы понять контракты. Лучше всего задеплоить их при помощи Remix.
 * Порядок деплоя:
 *      1. Задеплоить контрат Logic
 *      2. Задеплоить контракт Admin
 *      3. Задеплоить контракт LogicProxy(address Logic, address Admin, 0x)
 *      4. Задеплоить контракт LogicProxy с ABI контракта Logic при помощи встроенного в ремикс функционала "Deploy at address".
 *         Чтобы сделать это необходимо выбрать в поле CONTRACT - Logic, а в At установить адрес LogicProxy. Нажать на кнопку "At"
 *          Это позволит вызывать методы контракта Logic для контракта LogicProxy
 *      5. Задеплоить контракт Logic2. Этот контракт обновит логику контракта Logic. Будет добавлена новая функция increment()
 *      6. На контракте Admin вызвать upgrade() и передать туда адреса LogicProxy и Logic2
 *      7. Повторить пункт 4 но уже для контракта Logic2. Теперь у нас появился дополнительный метод increment().
 *         При этом состояние прокси не изменилось, там хранятся те же значения что были до обновления имплементации.
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
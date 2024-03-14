// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * Чтобы понять контракты. Лучше всего задеплоить их при помощи Remix.
 * Порядок деплоя:
 *      1. Задеплоить контрат Logic
 *      2. Задеплоить контракт LogicProxy(address Logic, address InitialOwner, 0x)
 *      3. Связать ABI контракта Logic с LogicProxy при помощи встроенного в Remix функционала "Deploy at address".
 *         Чтобы сделать это необходимо выбрать в поле CONTRACT - Logic, а в "At Address" установить адрес LogicProxy. Нажать на кнопку "At address"
 *          Это позволит вызывать методы контракта Logic для контракта LogicProxy
 *      4. Задеплоить контракт Logic2. Этот контракт обновит логику контракта Logic. Будет добавлена новая функция increment()
        5. Вызвать на контракте LogicProxy функцию "getAdmin()" чтобы получить адрес контракта администратора, затем связать ABI ProxyAdmin 
            с этим адресом, как это было проделано в пункте 3
 *      6. На контракте ProxyAdmin вызвать upgradeAndCall(address LogicProxy, address Logic2, 0x) и передать туда адреса LogicProxy, Logic2 и data (можно нулевую 0x)
 *      7. Повторить пункт 3 но уже для контракта Logic2. Теперь у нас появился дополнительный метод increment().
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

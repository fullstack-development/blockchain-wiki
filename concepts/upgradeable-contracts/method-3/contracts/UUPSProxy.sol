// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// Контракт логики
contract Logic is UUPSUpgradeable, OwnableUpgradeable {
    uint256 private _value;

    /**
     * @dev Так как в обновляемых контрактах нет конструктора, то нам необходимо использовать функцию initialize()
     * Дополнительно необходимо инициализировать контракт Ownable, так как он тоже обновляемый
     * Тот кто вызовет initialize() станет владельцем контракта Logic и сможет обновлять имплементацию для прокси
     */
    function initialize() external initializer {
       __Ownable_init();
   }

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }

    /**
     * @notice Проверка возможности обновлять контракт
     * @dev Согласно абстрактному контракту UUPSUpgradeable, нам обязательно необходимо переопределить данную функцию
     * При помощи собственной реализации функции мы будем определять возможность обновления контракта логики для контракта прокси
     * В рамках этого примера обновлять контракт логики может только владелец контракта логики
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

/// Контракт прокси
contract LogicProxy is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data
    ) ERC1967Proxy(_logic, _data) {}

    /// @notice Возвращает адрес установленного контракта логики для прокси
    function getImplemetation() public view returns (address) {
        return _implementation();
    }
}
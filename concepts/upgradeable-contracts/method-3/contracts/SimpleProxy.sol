// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Контракт с логикой реализации
contract Logic {
    address public initAddress;
    uint256 private _value;

    /**
     * @notice Используется для установки данных на контракт при инициализации
     * @dev По сути заменитель constructor()
     */
    function initialize(address _initAddress) public {
        initAddress = _initAddress;
    }

    /**
     * @notice Позволяет записать значение в state
     * @param _newValue Новое значение для записи в state
     */
    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    /**
     * @notice Позволяет получить значение из state
     * @return _value Значение из state
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/**
 * @notice Контракт прокси
 * @dev Не имеет реализации. Будет делегировать вызов контракту логики.
 * Фактическое хранение данных будет на контракте прокси.
 * Взаимодействие с контрактом логики только через вызовы на прокси контракте
 */
contract Proxy {
    struct AddressSlot {
        address value;
    }

    /**
     * @notice Внутренняя переменная для определения места записи информации об адресе контракта логики
     * @dev Согласно EIP-1967 слот можно рассчитать как bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
     * Выбираем псевдослучайный слот и записывае адрес контракта логики в этот слот. Эта позиция слота должна быть достаточно случайной,
     * чтобы переменная в контракте логики никогда не занимала этот слот.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address logic) {
        _setImplementation(logic);
    }

    /// @notice Возращает адрес установленного контракта логики для контракта прокси
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /// @notice Устанавливает адрес контракта логики для контракта прокси
    function setImplementation(address _newLogic) external {
        _setImplementation(_newLogic);
    }

    function _delegate(address _implementation) internal {
        // Необходима assembly вставка, потому что невозможно получить доступ к слоту для возврата значения в обычном solidity
        assembly {
            // Копируем msg.data и получаем полный контроль над памятью для этого вызова.
            calldatacopy(0, 0, calldatasize())

            // Вызываем контракт реализации
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // Копируем возвращаемые данные
            returndatacopy(0, 0, returndatasize())

            switch result
            // Делаем revert, если возвращенные данные равны нулю.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Возращает адрес установленного контракта логики для контракта прокси
     * @dev Адрес логики хранится в специально отведенном слоте, для того, чтобы невозможно было случайно затереть значение
     */
    function _getImplementation() internal view returns (address) {
        return getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @notice Устанавливает адрес контракта логики для котракта прокси
     * @dev Адрес логики хранится в специально отведенном слоте, для того, чтобы невозможно было случайно затереть значение
     */
    function _setImplementation(address newImplementation) private {
        getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @notice Возвращает произвольный слот памяти типа storage
     * @param slot Указатель на слот памяти storage
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /// @dev Любые вызовы функций контракта логики через прокси будут делегироваться благодаря обработке внутри fallback
    fallback() external {
        _delegate(_getImplementation());
    }
}
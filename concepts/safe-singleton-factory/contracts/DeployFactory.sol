// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract OurMultichainContract {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}

contract DeployFactory {
    error AlreadyDeployed();

    /// @notice Адрес Singleton Factory
    address constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    /// @notice Любая фиксированная соль
    bytes32 constant SALT = keccak256(bytes("any salt"));

    /// @notice Адрес owner, он будет "зашит" в байт-код
    /// Его смена приведет к смене результирующего адреса
    address public immutable owner = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;

    /// @notice Адрес развернутого смарт-контракта
    address public immutable ourMultichainContract;

    constructor() {
        /// Шаг 1. Вызываем Singleton Factory напрямую
        (bool success, bytes memory result) = SAFE_SINGLETON_FACTORY.call(
            abi.encodePacked(SALT, type(OurMultichainContract).creationCode, abi.encode(owner))
        );

        /// Шаг 2. Проверяем, что контракт еще не развернут
        if (!success) {
            revert AlreadyDeployed();
        }

        /// Шаг 3. Извлекаем адрес развернутого контракта
        ourMultichainContract = address(bytes20(result));
    }
}

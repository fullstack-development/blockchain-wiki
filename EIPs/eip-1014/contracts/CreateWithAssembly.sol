// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Foo {}

contract Bar {
    uint256 public balance;

    constructor() payable {
        balance = msg.value;
    }
}

contract Deployer {
    /// @notice Создание контракта через create без отправки ETH на новый адрес
    function deployFoo() public returns (address) {
        address foo;
        bytes memory initCode = type(Foo).creationCode;

        assembly {
            // Загружаем init code в память
            let codeSize := mload(initCode) // Размер init code
            let codeOffset := add(initCode, 0x20) // Пропускаем 32 байта для длины массива

            // Вызываем CREATE с без отправки msg.value
            foo := create(0, codeOffset, codeSize)
            // Проверяем, что контракт был успешно создан
            if iszero(foo) { revert(0, 0) }
        }

        return foo;
    }

    /// @notice Создание контракта через create с отправкой ETH на новый адрес
    function deployBar() public payable returns (address) {
        address bar;
        bytes memory initCode = type(Bar).creationCode;

        assembly {
            let codeSize := mload(initCode)
            let codeOffset := add(initCode, 0x20)
            bar := create(callvalue(), codeOffset, codeSize)
            if iszero(bar) { revert(0, 0) }
        }

        return bar;
    }

    /// @notice Вычисление адреса следующего контракта который будет развернут этим контрактом
    /// @dev Подсказка. Сразу после развертывания Deployer следующий nonce = 1
    function computeAddressWithCreate(uint256 _nonce) public view returns (address) {
        address _origin = address(this);
        bytes memory data;

        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data =
                abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data =
                abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data =
                abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data =
                abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Foo {}

contract Bar {
    uint256 public balance;

    constructor() payable {
        balance = msg.value;
    }
}

contract DeployerCreate2 {
    /// @notice Создание контракта через create2 без отправки ETH на новый адрес
    function create2Foo(bytes32 _salt) external returns (address) {
        Foo foo = new Foo{salt: _salt}();

        return address(foo);
    }

    /// @notice Создание контракта через create2 с отправкой ETH на новый адрес
    function create2Bar(bytes32 _salt) external payable returns (address) {
        Bar bar = new Bar{value: msg.value, salt: _salt}();

        return address(bar);
    }
}
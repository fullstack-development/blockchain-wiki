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
    function createFoo() external returns (address) {
        Foo foo = new Foo();

        return address(foo);
    }

    /// @notice Создание контракта через create с отправкой ETH на новый адрес
    function createBar() external payable returns (address) {
        Bar bar = new Bar{value: msg.value}();

        return address(bar);
    }
}

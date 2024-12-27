// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract First {
    function kill() public {
        selfdestruct(payable(address(0)));
    }
}

contract Second {
    uint256 public number;

    constructor(uint256 _number) {
        number = _number;
        emit SetNumber(_number);
    }

    event SetNumber(uint256 number);

    function setNumber(uint256 _number) external {
        number = _number;
        emit SetNumber(_number);
    }
}

contract Factory {
    function createFirst() public returns (address) {
        return address(new First());
    }

    function createSecond(uint256 _number) public returns (address) {
        return address(new Second(_number));
    }

    function kill() public {
        selfdestruct(payable(address(0)));
    }
}

contract MetamorphicContract {
    First private first;
    Second private second;
    Factory private factory;

    event FirstDeploy(address indexed factory, address indexed firstContractAddress);
    event SecondDeploy(address indexed factory, address indexed secondContractAddress);
    event CodeLength(uint256 codeLengthFactory, uint256 codeLengthChild);

    function firstDeploy() external {
        factory = new Factory{salt: keccak256(abi.encode("evil"))}();
        first = First(factory.createFirst());

        emit FirstDeploy(address(factory), address(first));

        first.kill();
        factory.kill();
    }

    function secondDeploy() external {
        /// Проверяем, что контракты удалены
        emit CodeLength(address(factory).code.length, address(first).code.length);

        /// Деплоим фабрику на тот же адрес
        factory = new Factory{salt: keccak256(abi.encode("evil"))}();

        /// Деплоим новый контракт на тот же адрес, что и первый
        second = Second(factory.createSecond(42));

        /// Проверяем, что адреса совпадают
        require(address(first) == address(second));

        /// Выполняем логику нового контракта
        second.setNumber(21);

        /// Логируем адреса
        emit SecondDeploy(address(factory), address(second));
    }
}

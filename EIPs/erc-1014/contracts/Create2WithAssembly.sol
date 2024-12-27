// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract TestContract {
    address public owner;
    uint256 public foo;

    constructor(address _owner, uint256 _foo) payable {
        owner = _owner;
        foo = _foo;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract FactoryAssembly {
    event Deployed(address addr, uint256 salt);

    // 1. Получение байткода контракта для развертывания
    // NOTE: _owner и _foo являются аргументами конструктора TestContract
    function getBytecode(address _owner, uint256 _foo)
        public
        pure
        returns (bytes memory)
    {
        bytes memory bytecode = type(TestContract).creationCode;

        return abi.encodePacked(bytecode, abi.encode(_owner, _foo));
    }

    // 2. Вычислите адрес контракта, который необходимо развернуть
    // NOTE: _salt - случайное число, используемое для создания адреса.
    function getAddress(bytes memory bytecode, uint256 _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), _salt, keccak256(bytecode)
            )
        );

        // NOTE: Переведите последние 20 байт хэша в адрес
        return address(uint160(uint256(hash)));
    }

    // 3. Развертывание контракта
    // NOTE:
    // Проверьте журнал событий Deployed, который содержит адрес развернутого TestContract.
    // Адрес в журнале должен быть равен адресу, вычисленному выше.
    function deploy(bytes memory bytecode, uint256 _salt) public payable {
        address addr;

        /*
        NOTE: Как вызвать create2

        create2(v, p, n, s)
        создайте новый контракт с кодом в памяти от p до p + n
        и отправить v wei
        и вернуть новый адрес
        где новый адрес = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
        assembly {
            addr :=
                create2(
                    callvalue(), // wei отправленный с текущим вызовом
                    // Фактический код начинается после пропуска первых 32 байт
                    add(bytecode, 0x20),
                    mload(bytecode), // Загрузите размер кода, содержащегося в первых 32 байтах
                    _salt // Соль из аргументов функции
                )

            if iszero(extcodesize(addr)) { revert(0, 0) }
        }

        emit Deployed(addr, _salt);
    }
}

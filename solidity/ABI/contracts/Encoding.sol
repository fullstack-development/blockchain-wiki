// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract TestContract {
    function someFunc(uint256 amount, address addr) public {}
}

// Полезные заметки
// 1. ABI - двоичный интерфейс контракта, стандартный способ взаимодействия с контрактами внутри экосистемы.
//    Селектор функции(function selector) - первые 4 байта определяют селектор функции.
//    Начиная с 5-го байта кодируются аргументы функции
//    Дальше кодируются типы(uint<M>, int<M>, address, uint, int, bool, ..., bytes<M, function> )
//    Некоторые типы не поддерживаются ABI напрямую (address payable, contract, enum, struct). Эти типы поддерживаются через стандартные типы.
//
//    Есть динамические типы(bytes, string, T[])
//    Есть статические типы(все остальные)
//
//    События бывают индексированные и неиндексированные. Здесь сложно.
//    Первые кодируются в специальный журнал и сложно читаются, но легко ищутся.
//    Вторые кодируются на месте, легко читаются, но сложно ищутся.
//
//    Ошибки кодируются, как функции.
//
//    encode - метод глобального объекта abi для вызова кодирования.
//    encodePacked - нестандартный метод кодирования, где максимально объединяются типы.
//                   Динамические типы кодируются на месте и без длины.
//                   Элементы массива дополняются, но кодируются на месте.
//
//    Ссылка на документацию: https://docs.soliditylang.org/en/v0.8.16/abi-spec.html#abi

// 2. Для конкатенации строк можно использовать abi.encodePacked
//    Пример: string(abi.encodePacked("Hi mom! ", "Miss you"));
//
//    Важно: С версии solidity 0.8.12 появился метод concat
//      Пример: string.concat(strA, strB);

// 3. Методы ниже encodeStringPacked и encodeStringsBytes дают одинаковый видимый результат.
//    Разница описана здесь https://forum.openzeppelin.com/t/difference-between-abi-encodepacked-string-and-bytes-string/11837
//    Первый — копирование памяти, второй — просто приведение типа указателя.
//    Важно: Приведение типа обходится дешевле по газу.

contract Encoding {
    // Конкатенация строк
    function combineStrings() public pure returns (string memory) {
        return string(abi.encodePacked("Hi mom! ", "Miss you"));
    }

    // Кодирование нескольких строк
    function combineBytesStrings() public pure returns (bytes memory) {
        return abi.encodePacked("Hi mom! ", "Miss you");
    }

    // Кодирование числа
    function encodeNumber() public pure returns(bytes memory) {
        bytes memory number = abi.encode(1);
        return number;
    }

    // Кодирование строки
    function encodeString() public pure returns(bytes memory) {
        bytes memory someString = abi.encode("some string");
        return someString;
    }

    // Альтернативный способ кодирования строки
    function encodeStringPacked() public pure returns(bytes memory) {
        bytes memory someString = abi.encodePacked("some string");
        return someString;
    }

    // Альтернативный способ кодирования строки
    function encodeStringsBytes() public pure returns(bytes memory) {
        bytes memory someString = bytes("some string");
        return someString;
    }

    // Декодирование строки
    function decodeString() public pure returns (string memory) {
        string memory someString = abi.decode(encodeString(), (string));
        return someString;
    }

    // Кодирование нескольких строк
    function multiEncode() public pure returns(bytes memory) {
        bytes memory someString = abi.encode("some string", "it's bigger");
        return someString;
    }

    // Декодирование нескольких строк
    function multiDecode() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncode(), (string, string));
        return (someString, someOtherString);
    }

    // Альтернативный способ кодирования нескольких строк
    function multiEncodePacked() public pure returns(bytes memory) {
        bytes memory someString = abi.encodePacked("some string", "it's bigger");
        return someString;
    }

    // Альтернативный способ декодирования нескольких строк
    // Этот вариант нельзя реализовать. В обратную сторону множественное декодирование работать не будет.
    // Так как при таком способе кодирования, мы избавляемся об информации пробелов и других лишних штук
    function multiDecodePacked() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncodePacked(), (string, string));
        return (someString, someOtherString);
    }

    // Альтернативный способ декодирования нескольких строк
    // Этот вариант рабочий.
    function multiStringCastPacked() public pure returns (string memory) {
        string memory someString = string(multiEncodePacked());
        return someString;
    }

    //========= Получение селектора функции и аргументов ========

    // Пример: получить селектор вызова функции из закодированных данных
    // Реальный кейс с которым пришлось столкнуться, когда из data вызова нужно получить отдельно селектор функции и аргументы функции
    function getFuncSelectorAndArgs() public view returns (bytes4 selector, bool isSelector, uint, address) {
        // Кодируем селектор функции с аргументом uint256
        bytes4 _selector = bytes4(keccak256("someFunc(uint256,address)"));
        bytes memory data = abi.encodeWithSelector(_selector, 100, msg.sender);

        // Получаем селектор функции
        selector = this.decodeFuncSelector(data);
        // Проверяем что селектор правильный
        isSelector = selector == TestContract.someFunc.selector;

        // Получаем аргументы функции
        (uint256 argument1, address argument2) = this.decodeFuncArguments(data);

        return (selector, isSelector, argument1, argument2);
    }

    // Получаем селектор функции
    function decodeFuncSelector(bytes calldata data) public pure returns (bytes4) {
        bytes4 selector = bytes4(data[:4]);
        return selector;
    }

    // Получаем аргументы
    function decodeFuncArguments(bytes calldata data) public pure returns(uint amount, address addr) {
        (amount, addr) = abi.decode(data[4:], (uint256, address));
        return (amount, addr);
    }
}

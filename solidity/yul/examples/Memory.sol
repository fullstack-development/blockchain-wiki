// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice В смарт-контракте отображены примеры приведенные в разделе Memory.
 * Примеры необходимо смотреть в отладчике
 */
contract Memory {
    uint256 value = 42;

    struct S {
        uint256 a;
        uint256 b;
    }

    // region - Read storage value

    function getValue() external view returns (uint256) {
        assembly {
            // Получаем значение для value, которое находится в соответствующем слоте
            let _value := sload(value.slot)

            // затем получаем "указатель" на свободную память memory
            let ptr := mload(0x40)

            // записываем туда наше число
            mstore(ptr, _value)

            // возвращаем это число
            return(ptr, 0x20)
        }
    }

    // endregion

    // region - Memory allocation

    function allocateMemory() external pure {
        assembly {
            // Выполняем некоторые операции в memory используя 3 слота
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 1)
            mstore(add(freeMemoryPointer, 0x20), 2)
            mstore(add(freeMemoryPointer, 0x40), 3)

            // вызываем функцию для обновления указателя
            allocate(0x60)

            // функция, которая получает размер памяти который мы использовали выше
            // и обновляет указатель на свободную память
            function allocate(length) {
                let pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }
        }
    }

    // endregion

    // region - Struct

    function getStructValuesAndFreeMemoryPointer()
        external
        pure
        returns (uint256 a, uint256 b, bytes32 freeMemoryPointer)
    {
        // Создаем структуру и добавляем туда значения
        S memory s = S({a: 21, b: 42});

        assembly {
            a := mload(0x80) // вернет a (21), потому что по умолчанию указатель на свободную память в solidity - 0x80
            b := mload(0xa0) // вернет b (42), второе значение в структуре размещается следом за первым

            // Новый указатель на свободную память - 0xc0 (0x80 + 32 байт * 2)
            freeMemoryPointer := mload(0x40)
        }
    }

    // endregion

    // region - Fixed array

    function getFixedArrayValues() external pure returns (uint256 a, uint256 b) {
        uint256[2] memory arr;
        arr[0] = 21;
        arr[1] = 42;

        assembly {
            a := mload(0x80) // вернет значение по индексу 0
            b := mload(0xa0) // вернет значение по индексу 1
        }
    }

    // endregion

    // region - Dynamic array

    function getDynamicArrayValues(uint256[] memory arr) external pure returns (uint256 a, uint256 b, uint256 length) {
        assembly {
            // местоположение - это первый свободный указатель: 0x80
            let ptr := arr
            // в нем находится длина массива
            length := mload(ptr)

            a := mload(add(ptr, 0x20)) // в следующей ячейке будет значение по индексу 0
            b := mload(add(ptr, 0x40)) // после по индексу 1 и т.д.
        }
    }

    function setValuesToDynamicArray() external pure returns (uint256[] memory) {
        uint256[] memory arr;

        // Создадим массив в memory = [42, 43]
        assembly {
            // сейчас arr указывает на 0x60

            // сначала присвоим ему указатель на свободную память
            arr := mload(0x40)
            // запишем длину будущего массива - 2 элемента
            mstore(arr, 2)
            // добавим значения в массив
            mstore(add(arr, 0x20), 42)
            mstore(add(arr, 0x40), 43)

            // обновим указатель на свободную память
            mstore(0x40, add(arr, 0x60))
        }

        return arr;
    }

    // endregion

    // region - Strings

    function getStringInfo() external pure returns (uint256 len, bytes21 strInBytes) {
        string memory str = "Hello, this is a test"; // 21 символ (0x15 в hex)

        assembly {
            len := mload(0x80) // в этом слоте будет длина массива
            strInBytes := mload(0xa0) // а в следующем сам массив
        }
    }

    function getString() external pure returns (string memory str) {
        str = "Hello, this is a test";
    }

    function getSeaport() external pure returns (string memory, uint256 len, bytes7 arr) {
        assembly {
            mstore(0x20, 0x20) // второй слот взят для схожести с ориг. примером
            mstore(0x40, 0x07) // сюда явно указываем длину
            mstore(0x60, 0x536561706f727400000000000000000000000000000000000000000000000000) // а сюда записываем только значения
            return(0x20, 0x60) // также возвращаем 96 байт
        }
    }

    function getSeaportSecondVariant() external pure returns (string memory, uint256 len, bytes7 arr) {
        assembly {
            // старый код закомментирую чтобы был перед глазами
            // mstore(0x20, 0x20)
            // mstore(0x47, 0x07536561706f7274)
            // return(0x20, 0x60)

            mstore(0x25, 0x20) // 0x20 + 5 = 0x25
            mstore(0x4c, 0x07536561706f7274) // 0x47 + 5 = 0x4c
            return(0x25, 0x60) // 0x20 + 5 = 0x25
        }
    }

    // endregion

    // region - ABI

    function abiEncode() external pure {
        abi.encode(uint256(1), uint256(2));

        assembly {
            let length := mload(0x80) // 0x0000...000040 (64 байт)
            let arg1 := mload(0xa0) // 0x0000...000001 (32 байт)
            let arg2 := mload(0xc0) // 0x0000...000002 (32 байт)
        }
    }

    function abiEncodePacked() external pure {
        abi.encodePacked(uint256(1), uint128(2));

        assembly {
            let length := mload(0x80) // 0x0000...000030 (48 байт)
            let arg1 := mload(0xa0) // 0x0000...000001 (32 байт)
            let arg2 := mload(0xc0) // 0x00...0002 (16 байт)
        }
    }

    // endregion

    // region - Return, revert

    function returnValues() external pure returns (uint256, uint256) {
        assembly {
            // запишем значения в слоты 0x80 и 0xa0
            mstore(0x80, 1)
            mstore(0xa0, 2)
            // вернем данные начиная со смещения 0x80 размером 0x40 (64 байте)
            return(0x80, 0x40)
        }
    }

    function revertExecution() external {
        assembly {
            if iszero(eq(mul(2, 2), 5)) { revert(0, 0) }
        }
    }

    // endregion

    // region - Keccak256

    function getKeccak() external pure {
        assembly {
            // запишем значения в слоты 0x80 и 0xa0
            mstore(0x80, 1)
            mstore(0xa0, 2)

            // хэшируем данные начиная с 0x80 размером 0x40 и сохраним их в слоте 0xc0
            mstore(0xc0, keccak256(0x80, 0x40))
        }
    }

    // endregion
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

/**
 * @notice В смарт-контракте отображены примеры приведенные в разделе Storage
 */
contract Storage {
    uint256 x; // slot 0

    uint128 a; // slot 1
    uint96 b; // slot 1
    uint16 c; // slot 1
    uint8 d; // slot 1
    uint8 e; // slot 1

    uint256[5] arr = [11, 22, 33, 44, 55]; // slot 2 - 6
    uint256 amount; // slot 7
    uint128[2] packedArr = [21, 42]; // slot 8
    uint256 amount2; // slot 9

    uint256[] dynamicArr = [123, 345, 678]; // slot 10

    mapping(uint256 => uint256) map; // slot 11
    mapping(uint256 => mapping(uint256 => uint256)) nestedMap; // slot 12
    mapping(address => uint256[]) arrayInMap; // slot 13

    /// Все три строки обрабатывает одна функция, поэтому просто раскоментируйте нужную
    string str = "Hello, world!"; // slot 14
    // string str = "Hello, this is a test phrase 02";
    // string str = "Hello, this is a test phrase for wiki";

    constructor() {
        map[42] = 21;
        nestedMap[4][2] = 21;
        arrayInMap[msg.sender] = [11, 22, 33];
    }

    // region - Simple value

    function setStorageValue(uint256 _x) public {
        assembly {
            sstore(x.slot, _x)
        }
    }

    function getStorageValue() public view returns (uint256 ret) {
        assembly {
            ret := sload(x.slot)
        }
    }

    // endregion

    // region - Packed values

    function setCToPackedSlot(uint16 _c) public {
        assembly {
            // Загружаем данные из слота
            let data := sload(c.slot)

            // Обнуляем биты переменной в которых хранится переменная.
            // Так как это uint16, он занимает 2 байта
            let cleared := and(data, 0xffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

            // Сдвигаем новое значение влево на смещение переменной умноженное на 8 (1 байт = 8 бит)
            // Дело в том, что offset возвращает число в байтах, а сдвиг мы делаем  в битах
            let shifted := shl(mul(c.offset, 8), _c)

            // Объединяем очищенный слот и сдвинутое значение
            let newValue := or(shifted, cleared)

            // Сохраняем новое значение в слоте
            sstore(c.slot, newValue)
        }
    }

    function getCFromPackedSlot() public view returns (uint16 ret) {
        assembly {
            // Загружаем данные из слота
            let data := sload(c.slot)

            // Делаем сдвиг вправо используя смещение необходимой переменной
            let shifted := shr(mul(c.offset, 8), data)

            // Применяем маску, чтобы получить значение переменной
            ret := and(shifted, 0xffff)
        }
    }

    // endregion

    // region - Array, packed array

    function getValueFromArray(uint256 index) public view returns (uint256 value) {
        assembly {
            value := sload(add(arr.slot, index))
        }
    }

    function getPackedValueFromArray() public view returns (uint128 value) {
        bytes32 packed;

        assembly {
            // Загружаем упакованные данные
            packed := sload(packedArr.slot)

            // Делаем сдвиг вправо на 16 байт (128 бит),
            // чтобы получить значение массива по индексу 1
            value := shr(mul(16, 8), packed)
        }
    }

    // endregion

    // region - Dynamic array

    function getValueFromDynamicArray(uint256 index) external view returns (uint256 value) {
        uint256 slot;

        assembly {
            // Получаем слот в котором лежит длина массива
            slot := dynamicArr.slot

            // Вычисляем хеш который укажет на слот где хранятся значения массива
            // Эквивалентно записи в solidity:
            // bytes32 ptr = keccak256(abi.encode(slot));
            mstore(0x00, slot)
            let ptr := keccak256(0x00, 0x20)

            // Загружаем необходимый элемент массива по индексу
            value := sload(add(ptr, index))
        }
    }

    function getDynamicArrayLength() external view returns (uint256 length) {
        assembly {
            length := sload(dynamicArr.slot)
        }
    }

    // endregion

    // region - Mappings
    function getValueFromMapping(uint256 key) public view returns (uint256 value) {
        bytes32 slot;

        assembly {
            // Получаем слот маппинга
            slot := map.slot

            // Вычисляем хеш который укажет на слот где хранятся значения маппинга
            // Эквивалентно записи в solidity:
            // bytes32 ptr = keccak256(abi.encode(key, uint256(slot)));
            mstore(0x00, key)
            mstore(0x20, slot)
            let ptr := keccak256(0x00, 0x40)

            // Загружаем необходимый элемент маппинга
            value := sload(ptr)
        }
    }

    function getValueFromNestedMapping(uint256 key1, uint256 key2) public view returns (uint256 value) {
        bytes32 slot;
        assembly {
            slot := nestedMap.slot

            // bytes32 ptr2 = keccak256(abi.encode(key2, keccak256(abi.encode(key1, uint256(slot)))));
            mstore(0x00, key1)
            mstore(0x20, slot)
            let ptr1 := keccak256(0x00, 0x40)

            mstore(0x00, key2)
            mstore(0x20, ptr1)
            let ptr2 := keccak256(0x00, 0x40)

            value := sload(ptr2)
        }
    }

    function getValueFromArrayNestedInMapping(address key, uint256 index)
        public
        view
        returns (uint256 value, uint256 length)
    {
        bytes32 slot;

        assembly {
            slot := arrayInMap.slot
        }

        bytes32 arrSlot = keccak256(abi.encode(key, slot));
        bytes32 ptr = keccak256(abi.encode(arrSlot));

        assembly {
            value := sload(add(ptr, index))
            length := sload(arrSlot)
        }
    }

    // endregion

    // region - Strings

    function getStringInfo() external view returns (uint256 length, bytes32 lsb, bytes32 strBytes, bytes32 slot) {
        assembly {
            // Кешируем слот
            slot := str.slot
            // Загружаем содержимое слота
            strBytes := sload(slot)
            // Копируем содержимое, чтобы получить младший бит
            let _arr := strBytes
            // Получаем значение младшего бита
            lsb := and(_arr, 0x1)

            // Проверяем, равен ли он 0
            if iszero(lsb) {
                // Берем младший байт и делим на 2 чтобы получить длину строки
                length := div(byte(31, strBytes), 2)
            }

            // Проверяем, если больше 0
            if gt(lsb, 0) {
                // Отнимаем 1 и делим на 2 чтобы получить длину строки
                length := div(sub(strBytes, 1), 2)

                // Записываем в memory номер слота
                mstore(0x00, slot)
                // Получаем хеш слота, чтобы узнать где фактически лежит строка
                slot := keccak256(0x00, 0x20)
            }
        }
    }

    // endregion
}

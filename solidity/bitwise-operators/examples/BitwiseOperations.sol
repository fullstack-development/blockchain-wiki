// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract BitwiseOperations {
    // проверка бита по индексу
    /**
     *  00110010 & 00000010 = 00000010
     *  number = 50
     *  index = 0 == false
     *  index = 1 == true
     *  index = 2 == false
     *  ...
     *  index = 4 == true
     */
    function isSetBit(uint8 number, uint8 index) external pure returns (bool) {
        return number & (1 << index) != 0;
    }

    // установка бита в 1
    /**
     *  00110000 | 00000010 = 00110010
     *  number = 48
     *  index = 1
     *  result = 50
     */
    function setBit(uint8 number, uint8 index) external pure returns (uint256) {
        return number | (1 << index);
    }

    // установка бита в 0
    /**
     *  00110010 ^ 11111101 = 00110000
     *  number = 50
     *  index = 1
     *  result = 48
     */
    function resetBit(uint8 number, uint8 index) external pure returns (uint256) {
        return number & ~(1 << index);
    }

    // инверсия бита
    /**
     *  00110000 ^ 00000010 = 00110010
     *  number = 48
     *  index = 1
     *  result = 50
     */
    function inverseBit(uint8 number, uint8 index) external pure returns (uint256) {
        return number ^ (1 << index);
    }
}

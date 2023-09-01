// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice Пример из раздела Calldata
 */
contract Calldata {
    function getString(string calldata) external pure returns (string memory, uint256 len) {
        assembly {
            // получаем смещение строки, добавляем 4 байта сигнатуры чтобы скорректировать смещение
            let strOffset := add(4, calldataload(4))
            // получаем длину строки
            len := calldataload(strOffset)
            // получаем указатель на свободную память
            let ptr := mload(0x40)
            // вычисляем размер данных без сигнатуры
            let dataSize := sub(calldatasize(), 4)
            // копируем в memory все данные о строке кроме сигнатуры
            calldatacopy(ptr, 0x04, dataSize)

            // возвращаем строку
            return(0x80, dataSize)
        }
    }
}

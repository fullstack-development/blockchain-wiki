// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Бинарный поиск
 * @notice Контракт реализует функцию binarySearch(),
 * которая выполняет поиску элемента в отсортированном списке
 */
contract BinarySearch {
    uint256[] private _list;

    /// @notice Возврат, когда искомый элемент не найден в списке
    error None();

    /// @notice Возврат, когда размер создаваемого списка равен нулю
    error ZeroSize();

    constructor(uint256 size) {
        if (size == 0) {
            revert ZeroSize();
        }

        _createList(size);
    }

    /**
     * @notice Бинарный поиск
     * @param desiredValue Искомое значение
     */
    function binarySearch(uint256 desiredValue) external view returns (uint256) {
        /// Переменные для хранения границ списка, в которой выполняется поиск
        uint256 start = 0;
        uint256 end = _list.length - 1;

        /// Ведем поиск, пока не будет найден искомый элемент
        while (start <= end) {
            uint256 middle = (start + end) / 2;
            uint256 guessedValue = _list[middle];

            if (guessedValue == desiredValue) {
                return middle; /// Значение найдено
            }

            if (desiredValue < guessedValue) {
                end = middle - 1; /// Искомый элемент находится в левой половине
            } else {
                start = middle + 1; /// Искомый элемент находится в правой половине
            }
        }

        revert None();
    }

    /**
     * @notice Инициализация отсортированного списка
     * @param size Размер создаваемого отсортированного списка
     */
    function _createList(uint256 size) private {
        for (uint256 i = 0; i < size; i++) {
            _list.push(i);
        }
    }
}

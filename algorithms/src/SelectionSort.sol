// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @notice Направление сортировки
enum SortDirection {
    ASC,
    DESC
}

/**
 * @title Сортировка выбором
 * @notice Контракт реализует функцию sort() для сортировки элементов массива выбором
 */
contract SelectionSort {
    /**
     * @notice Сортировка выбором
     * @param arr Неотсортированный массив чисел
     * @param sortDirection Направление сортировки
     */
    function sort(uint256[] memory arr, SortDirection sortDirection)
        external
        pure
        returns
        (uint256[] memory sortedArr)
    {
        /// Объявляем массив, в который будем записывать отсортированные элементы исходного массива
        sortedArr = new uint256[](arr.length);

        for (uint256 i = 0; i < arr.length; i++) {
            /// Сортировка по возрастанию
            if (sortDirection == SortDirection.ASC) {
                uint256 index = _findSmallest(arr);
                sortedArr[i] = arr[index];

                /// Идентично удалению элемента из массива или переставлению элементов местами
                arr[index] = type(uint256).max;
            }

            /// Сортировка по убыванию
            if (sortDirection == SortDirection.DESC) {
                uint256 index = _findBiggest(arr);
                sortedArr[i] = arr[index];

                /// Идентично удалению из массива или переставлению элементов
                arr[index] = type(uint256).min;
            }
        }
    }

    /**
     * @notice Поиск самого маленького значения в массиве
     * @param arr Неотсортированный массив чисел
     */
    function _findSmallest(uint256[] memory arr) private pure returns (uint256 smallestIndex) {
        uint256 smallest = arr[0];
        smallestIndex = 0;

        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] < smallest) {
                smallest = arr[i];
                smallestIndex = i;
            }
        }
    }

    /**
     * @notice Поиск самого большого значения в массиве
     * @param arr Неотсортированный массив чисел
     */
    function _findBiggest(uint256[] memory arr) private pure returns (uint256 biggestIndex) {
        uint256 biggest = arr[0];
        biggestIndex = 0;

        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > biggest) {
                biggest = arr[i];
                biggestIndex = i;
            }
        }
    }
}
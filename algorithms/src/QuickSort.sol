// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Быстрая сортировка
 * @notice Контракт реализует функцию sort(),
 * которая выполняет алгоритм быстрой сортировки для массива чисел
 */
contract QuickSort {
    error ArrayZero();

    /**
     * @notice Сортирует массив чисел
     * @param arr Массив чисел
     */
    function sort(uint256[] memory arr) external returns(uint256[] memory) {
        if (arr.length == 0) {
            revert ArrayZero();
        }

        /// Рекурсивно запускаем быструю сортировку.
        /// Для первого запуска указываем весь диапазон массива
       _quickSort(arr, int256(0), int256(arr.length - 1));

       return arr;
    }

    /**
     * @notice Приватная функция быстрой сортировки. Необходима для рекурсивного вызова
     * @param arr Массив чисел
     * @param left Индекс левой границы массива
     * @param right Индекс правой границы массива
     */
    function _quickSort(uint256[] memory arr, int256 left, int256 right) private {
        int256 i = left;
        int256 j = right;

        if (i==j) {
            return;
        }

        /// Выбираем опорный элемент массива по середине
        uint256 pivot = arr[uint256(left + (right - left) / 2)];

        while (i <= j) {
            /// Находим индекс элемента, который будет больше опорного.
            /// То есть находится левее него, а должен находиться правее
            while (arr[uint256(i)] < pivot) {
                i++;
            }

            /// Находим индекс элемента, который будет меньше опорного.
            /// То есть находится правее него, а должен находиться левее
            while (pivot < arr[uint256(j)]) {
                j--;
            }

            if (i <= j) {
                /// Меняем местами найденные элементы
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);

                /// Повлияет на уменьшение диапазона для рекурсивного вызова
                i++;
                j--;
            }
        }

        /// Делаем рекурсивный вызов
        if (left < j) {
            _quickSort(arr, left, j);
        }

        if (i < right) {
            _quickSort(arr, i, right);
        }
    }
}
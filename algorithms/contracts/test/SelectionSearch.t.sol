// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {SelectionSort, SortDirection} from "../src/SelectionSort.sol";

contract SelectionSortTest is Test {
    SelectionSort public selectionSort;
    uint256[] public rawArr = [9, 0, 1, 5, 3, 4, 10, 6, 8, 7, 2];
    uint256[] public rawArrWithRepeatValue = [9, 0, 1, 5, 9, 3, 10, 4, 10, 6, 2, 8, 7, 2];

    function setUp() external {
        selectionSort = new SelectionSort();
    }

    function test_sort_asc() external {
        uint256[] memory sortedArr = selectionSort.sort(rawArr, SortDirection.ASC);

        assertEq(sortedArr.length, rawArr.length);

        for (uint256 i = 0; i < sortedArr.length; i++) {
            if (i == 0) {
                continue;
            }

            assertTrue(sortedArr[i] > sortedArr[i - 1]);
        }
    }

    function test_sort_desc() external {
        uint256[] memory sortedArr = selectionSort.sort(rawArr, SortDirection.DESC);

        assertEq(sortedArr.length, rawArr.length);

        for (uint256 i = 0; i < sortedArr.length; i++) {
            if (i == 0) {
                continue;
            }

            assertTrue(sortedArr[i] < sortedArr[i - 1]);
        }
    }

    function test_sort_repeatValue_asc() external {
        uint256[] memory sortedArr = selectionSort.sort(rawArrWithRepeatValue, SortDirection.ASC);

        assertEq(sortedArr.length, rawArrWithRepeatValue.length);

        for (uint256 i = 0; i < sortedArr.length; i++) {
            if (i == 0) {
                continue;
            }

            assertTrue(sortedArr[i] >= sortedArr[i - 1]);
        }
    }

    function test_sort_repeatValue_desc() external {
        uint256[] memory sortedArr = selectionSort.sort(rawArrWithRepeatValue, SortDirection.DESC);

        assertEq(sortedArr.length, rawArrWithRepeatValue.length);

        for (uint256 i = 0; i < sortedArr.length; i++) {
            if (i == 0) {
                continue;
            }

            assertTrue(sortedArr[i] <= sortedArr[i - 1]);
        }
    }
}

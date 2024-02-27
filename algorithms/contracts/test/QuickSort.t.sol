// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {QuickSort} from "../src/QuickSort.sol";

contract QuickSortTest is Test {
    QuickSort quickSort;
    uint256[] public rawArr = [1, 3, 6, 2, 10, 9, 4, 7, 5, 8];
    uint256[] public rawArrWithOneItem = [2023];
    uint256[] public rawArrWithZeroItem;
    uint256[] public rawArrWithRepeatedItem = [1, 3, 3, 6, 2, 10, 9, 4, 6, 7, 5, 8, 10];

    function setUp() external {
        quickSort = new QuickSort();
    }

    function test_quickSort() external {
        uint256[] memory sortedArr = quickSort.sort(rawArr);

        for (uint256 i = 0; i < rawArr.length; i++) {
            assertEq(sortedArr[i], i + 1);
        }
    }

    function test_quickSort_withOneItem() external {
        uint256[] memory sortedArr = quickSort.sort(rawArrWithOneItem);

        assertEq(sortedArr[0], rawArrWithOneItem[0]);
    }

    function test_quickSort_withZeroItem() external {
        vm.expectRevert(abi.encodeWithSignature("ArrayZero()"));

        quickSort.sort(rawArrWithZeroItem);
    }

    function test_quickSort_withRepeatedItem() external {
        uint256[] memory sortedArr = quickSort.sort(rawArrWithRepeatedItem);

        uint256 lastItem = 0;
        for (uint256 i = 0; i < rawArrWithRepeatedItem.length; i++) {
            assertTrue(sortedArr[i] >= lastItem);
        }
    }
}
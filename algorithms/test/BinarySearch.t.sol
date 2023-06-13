// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BinarySearch.sol";

contract BinarySearchTest is Test {
    uint256 constant public LIST_SIZE_EVEN = 200;
    uint256 constant public LIST_SIZE_ODD = 333;
    uint256 constant public LIST_SIZE = 400;

    BinarySearch public binarySearchWithEvenListSize;
    BinarySearch public binarySearchWithOddListSize;
    BinarySearch public binarySearchWithOneSize;
    BinarySearch public binarySearch;

    function setUp() external {
        binarySearchWithEvenListSize = new BinarySearch(LIST_SIZE_EVEN);
        binarySearchWithOddListSize = new BinarySearch(LIST_SIZE_ODD);
        binarySearchWithOneSize = new BinarySearch(1);
        binarySearch = new BinarySearch(LIST_SIZE);
    }

    function test_binarySearch_evenListSize() external {
        uint256 desiredValue = 157;

        uint256 desiredIndex = binarySearchWithEvenListSize.binarySearch(desiredValue);

        assertEq(desiredIndex, desiredValue);
    }

    function test_binarySearch_oddListSize() external {
        uint256 desiredValue = 152;

        uint256 desiredIndex = binarySearchWithOddListSize.binarySearch(desiredValue);

        assertEq(desiredIndex, desiredValue);
    }

    function test_binarySearch_revertIfNoneValue(uint256 noneDesiredValue) external {
        vm.assume(noneDesiredValue >= LIST_SIZE);
        vm.expectRevert(abi.encodeWithSignature("None()"));

        binarySearch.binarySearch(noneDesiredValue);
    }

    function test_binarySearch_searchFirstItem() external {
        uint256 desiredValue = 0;

        uint256 desiredIndex = binarySearch.binarySearch(desiredValue);

        assertEq(desiredIndex, desiredValue);
    }

    function test_binarySearch_searchLastItem() external {
        uint256 desiredValue = LIST_SIZE - 1;

        uint256 desiredIndex = binarySearch.binarySearch(desiredValue);

        assertEq(desiredIndex, desiredValue);
    }

    function test_binarySearch_revertIfZeroSize() external {
        vm.expectRevert(abi.encodeWithSignature("ZeroSize()"));
        new BinarySearch(0);
    }
}

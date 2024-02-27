// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Queue} from "../src/libraries/Queue.sol";

contract QueueTest is Test {
    using Queue for Queue.Info;

    Queue.Info private _queue;

    function test_enqueue() external {
        string memory str = "test";

        _queue.enqueue(str);

        assertEq(_queue.length(), 1);
    }

    function test_dequeue() external {
        string memory str = "test";
        _queue.enqueue(str);

        string memory resultStr = _queue.dequeue();

        assertEq(_queue.length(), 0);
        assertEq(
            keccak256(abi.encodePacked(str)),
            keccak256(abi.encodePacked(resultStr))
        );
    }

    function test_dequeue_revertIfQueueZero() external {
        string memory str = "test";
        _queue.enqueue(str);

        _queue.dequeue();

        vm.expectRevert(abi.encodeWithSignature("ZeroQueue()"));

        _queue.dequeue();
    }

    function test_enqueue_and_dequeue_multiple() external {
        string memory str1 = "test";
        string memory str2 = "test2";
        string memory str3 = "test2";

        _queue.enqueue(str1);
        _queue.enqueue(str2);
        _queue.enqueue(str3);

        string memory resultStr = _queue.dequeue();

        assertEq(_queue.length(), 2);
        assertEq(
            keccak256(abi.encodePacked(str1)),
            keccak256(abi.encodePacked(resultStr))
        );
    }
}
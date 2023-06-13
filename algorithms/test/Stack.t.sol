// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Stack} from "../src/libraries/Stack.sol";

contract StackTest is Test {
    using Stack for bytes[];

    bytes[] private _stack;

    function test_push() external {
        bytes memory str = bytes("test");
        _stack.pushTo(str);

        assertEq(_stack.length, 1);
        assertEq(_stack[0], str);
    }

    function test_pop() external {
        bytes memory str = bytes("test");
        _stack.pushTo(str);

        bytes memory resultStr = _stack.popOut();

        assertEq(_stack.length, 0);
        assertEq(resultStr, str);
    }

    function test_pop_doublePop() external {
        bytes memory str = bytes("test");
        _stack.pushTo(str);

        _stack.popOut();

        vm.expectRevert();

        _stack.popOut();
    }
}
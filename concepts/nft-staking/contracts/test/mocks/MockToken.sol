// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract MockToken is MockERC20 {
    constructor () {
        initialize("MockToken", "MT", 18);
    }

    function mint(address account, uint256 value) external {
        _mint(account, value);
    }
}
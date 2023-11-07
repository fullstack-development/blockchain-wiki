// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping (address account => bool isIncluded) private _whitelists;

    constructor (address governor) Ownable(governor) {}

    function set(address account) external onlyOwner() returns (bool) {
        return _whitelists[account] = true;
    }

    function isIncluded(address account) external view returns (bool) {
        return _whitelists[account];
    }
}
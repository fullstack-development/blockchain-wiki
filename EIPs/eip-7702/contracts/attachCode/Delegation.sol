// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation
 * @author Pavel Naydanov
 */
contract Delegation {
    uint256 private _value;

    constructor(uint256 initialValue) {
        _value = initialValue;
    }

    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}
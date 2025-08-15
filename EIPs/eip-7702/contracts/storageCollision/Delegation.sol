// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation first
 * @author Pavel Naydanov
 * @notice Показываем работу хранилища
 */
contract DelegationFirst {
    uint256 private _value;

    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}

/**
 * @title Delegation second
 * @author Pavel Naydanov
 * @notice Показываем работу хранилища
 */
contract DelegationSecond {
    bytes32 private _hashValue;

    function setHash(bytes32 hashValue) external {
        _hashValue = hashValue;
    }

    function getHash() external view returns (bytes32) {
        return _hashValue;
    }
}
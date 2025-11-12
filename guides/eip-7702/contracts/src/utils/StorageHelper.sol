// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

abstract contract StorageHelper {
    // keccak256(abi.encode(uint256(keccak256("MetaLamp.Wallet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _STORAGE_LOCATION = 0xa3c7fb5ee0843e27cf3d06e1a75ae4fe5241c2d945da24d804adf753e5643900;

    struct Storage {
        mapping(bytes32 salt => bool isUsed) isSaltUsed;
        mapping(bytes32 salt => bool isCancelled) isSaltCancelled;
    }

    function _getStorage() internal pure virtual returns (Storage storage $) {
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}

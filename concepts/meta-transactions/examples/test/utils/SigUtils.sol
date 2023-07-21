// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract SigUtils {
    bytes32 immutable private _domainSeparator;

    struct MetaTransaction {
        uint256 nonce;
        address signer;
        bytes functionSignature;
    }

    constructor(bytes32 domainSeparator) {
        _domainSeparator = domainSeparator;
    }

    function _getStructHash(bytes32 typeHash, MetaTransaction memory _tx) private pure returns (bytes32) {
        return keccak256(abi.encode(typeHash, _tx.nonce, _tx.signer, keccak256(_tx.functionSignature)));
    }

    function getTypedDataHash(bytes32 typeHash, MetaTransaction memory _tx) external view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _getStructHash(typeHash, _tx)));
    }
}

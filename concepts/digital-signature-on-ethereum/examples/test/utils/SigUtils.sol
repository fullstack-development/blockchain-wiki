// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    struct Params {
        uint256 nonce;
    }

    function getStructHash(Params memory _params, bytes32 typeHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    _params.nonce
                )
            );
    }

    function getTypedDataHash(Params memory _params, bytes32 typeHash)
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_params, typeHash)
                )
            );
    }
}

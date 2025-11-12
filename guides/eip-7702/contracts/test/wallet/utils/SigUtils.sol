// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ExecutionRequest} from "src/wallet/libraries/WalletValidator.sol";

contract SigUtils {
    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant WALLET_OPERATION_TYPEHASH = keccak256(
        abi.encodePacked(
            "WalletSignature(bytes32 mode,bytes executionCalldata,bytes32 salt,uint64 deadline,address sender)"
        )
    );

    constructor(address verifyingContract) {
        DOMAIN_SEPARATOR = _domainSeparator(verifyingContract);
    }

    function test() public {}

    function _domainSeparator(address verifyingContract) private view returns (bytes32) {
        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Wallet"),
                keccak256("1"),
                chainId,
                verifyingContract
            )
        );
    }

    function getDigest(ExecutionRequest memory request, address sender) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _getWalletHash(request, sender)));
    }

    function _getWalletHash(ExecutionRequest memory request, address sender) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                WALLET_OPERATION_TYPEHASH,
                request.mode,
                keccak256(request.executionCalldata),
                request.salt,
                request.deadline,
                sender
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ModeCode} from "@erc7579/lib/ModeLib.sol";

struct ExecutionRequest {
    ModeCode mode;
    bytes executionCalldata;
    bytes32 salt;
    uint64 deadline;
}

library WalletValidator {
    bytes32 public constant WALLET_OPERATION_TYPEHASH = keccak256(
        abi.encodePacked(
            "WalletSignature(bytes32 mode,bytes executionCalldata,bytes32 salt,uint64 deadline,address sender)"
        )
    );

    error RequestExpired();
    error SaltAlreadyUsed();
    error SaltCancelled();
    error InvalidSignature();

    function isValidERC1271Signature(bytes32 digest, bytes calldata signature) internal view returns (bool) {
        return ECDSA.recover(digest, signature) == address(this);
    }

    function checkRequest(
        ExecutionRequest memory request,
        bytes calldata signature,
        mapping(bytes32 salt => bool isUsed) storage isSaltUsed,
        mapping(bytes32 salt => bool isCancelled) storage isSaltCancelled
    ) internal view {
        if (block.timestamp > request.deadline) {
            revert RequestExpired();
        }

        if (isSaltUsed[request.salt]) {
            revert SaltAlreadyUsed();
        }

        if (isSaltCancelled[request.salt]) {
            revert SaltCancelled();
        }

        bool isValid = _isValidSignature(request, signature);
        if (!isValid) {
            revert InvalidSignature();
        }
    }

    function _isValidSignature(ExecutionRequest memory request, bytes calldata signature) private view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), _getDigest(request)));
        return ECDSA.recover(digest, signature) == address(this);
    }

    function _domainSeparator() private view returns (bytes32) {
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
                address(this)
            )
        );
    }

    function _getDigest(ExecutionRequest memory request) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                WALLET_OPERATION_TYPEHASH,
                request.mode,
                keccak256(request.executionCalldata),
                request.salt,
                request.deadline,
                msg.sender
            )
        );
    }
}

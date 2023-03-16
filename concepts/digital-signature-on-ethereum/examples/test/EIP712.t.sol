// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {SigUtils} from "./utils/SigUtils.sol";
import {EIP712} from "../src/EIP712.sol";

contract EIP712Test is Test {
    SigUtils internal sigUtils;
    EIP712 internal verifier;

    function setUp() external {
        verifier = new EIP712();
        sigUtils = new SigUtils(verifier.DOMAIN_SEPARATOR());
    }

    function test_isValid() external {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);

        SigUtils.Params memory params = SigUtils.Params({
            nonce: verifier.signatureNonce() + 1
        });

        bytes32 digest = sigUtils.getTypedDataHash(params, verifier.IS_VALID_TYPEHASH());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertTrue(verifier.isValid(signer, signature));
    }

    function test_isInvalid() external {
        uint256 privateKey = 1;
        address notSigner = vm.addr(2);

        SigUtils.Params memory params = SigUtils.Params({
            nonce: verifier.signatureNonce() + 1
        });

        bytes32 digest = sigUtils.getTypedDataHash(params, verifier.IS_VALID_TYPEHASH());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertFalse(verifier.isValid(notSigner, signature));
    }

    function test_useSignature() external {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);

        SigUtils.Params memory params = SigUtils.Params({
            nonce: verifier.signatureNonce() + 1
        });

        bytes32 digest = sigUtils.getTypedDataHash(params, verifier.IS_VALID_TYPEHASH());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 signatureNonceOld = verifier.signatureNonce();

        verifier.useSignature(signer, signature);

        assertEq(verifier.signatureNonce(), signatureNonceOld + 1);
    }

    function test_useSignature_revertIfSignatureIsInvalid() external {
        uint256 privateKey = 1;
        address notSigner = vm.addr(2);

        SigUtils.Params memory params = SigUtils.Params({
            nonce: verifier.signatureNonce() + 1
        });

        bytes32 digest = sigUtils.getTypedDataHash(params, verifier.IS_VALID_TYPEHASH());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSignature("SignatureIsInvalid()"));

        verifier.useSignature(notSigner, signature);
    }
}

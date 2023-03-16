// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import {SignatureVerifier} from "../src/SignatureVerifier.sol";

contract SignatureVerifierTest is Test {
    SignatureVerifier verifier;

    function setUp() external {
        verifier = new SignatureVerifier();
    }

    function test_isValid() external {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);
        bytes32 message = "Hello";

        bytes32 prefixedHash = keccak256(abi.encodePacked(verifier.PREFIX(), message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, prefixedHash);

        assertTrue(verifier.isValid(signer, message, v, r, s));
    }

    function test_isInvalid() external {
        uint256 privateKey = 1;
        address notSigner = vm.addr(2);
        bytes32 message = "Hello";

        bytes32 prefixedHash = keccak256(abi.encodePacked(verifier.PREFIX(), message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, prefixedHash);

        assertFalse(verifier.isValid(notSigner, message, v, r, s));
    }
}
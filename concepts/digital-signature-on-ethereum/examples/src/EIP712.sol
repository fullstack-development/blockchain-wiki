// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice Контракт проверяет подписанное приватным ключом сообщение c типизированными данными согласно EIP-712.
 * @dev Используется библиотека от OpenZeppelin ECDSA
 */
contract EIP712 {
    bytes32 public constant IS_VALID_TYPEHASH = keccak256("isValid(uint256 nonce)");

    /// @notice Счетчик проверки подписи. Позволяет быть уверенным, что одна и таже подпись не бует использована дважды
    uint256 public signatureNonce;

    error SignatureIsInvalid();

    /// @notice 32-байтовый разделитель домена. Используется для определения свойств конкретного приложения.
    /// Другими словами подпись может использоваться только для этого приложения
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("EIP712"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice hashStruct. Используется для определения типизированных данных подписи
    function _getDigest(bytes32 typeHash) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", // Согласно EIP-191. Фиксированное значение версии. Определяет "Structured data" EIP-712
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        typeHash,
                        signatureNonce + 1
                    )
                )
            )
        );
    }

    /**
     * @notice Проверяет была ли подпись сделана адресом signer
     * @param signer Публичный адрес для проверки, подписавший сообщение
     * @param signature Проверяемая подпись (abi.encoded(r, s, v))
     */
    function isValid(address signer, bytes memory signature) public view returns (bool) {
        bytes32 digest = _getDigest(IS_VALID_TYPEHASH);
        address recoveredSigner = ECDSA.recover(digest, signature);

        return signer == recoveredSigner;
    }

    function useSignature(address signer, bytes memory signature) external {
        if (!isValid(signer, signature)) {
            revert SignatureIsInvalid();
        }

        signatureNonce += 1;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @notice Контракт проверяет подписанное приватным ключом произвольное сообщение
 * @dev Используется встроенная функция ecrecover()
 */
contract SignatureVerifier {
    /// @notice Префикс для обозначения, что эта подпись будет использоваться только внутри сети Ethereum
    bytes32 constant public PREFIX = "\x19Ethereum Signed Message:\n32";

    /// @notice Проверяет была ли подпись сделана адресом signer
    function isValid(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) external pure returns (bool) {
        return _recover(hash, v, r, s) == signer;
    }

    /// @notice Восстанавливает публичный адрес приватного ключа, которым была сделана передаваямая подпись
    function _recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) private pure returns (address) {
        bytes32 prefixedHash = keccak256(abi.encodePacked(PREFIX, hash));

        return ecrecover(prefixedHash, v, r, s);
    }
}
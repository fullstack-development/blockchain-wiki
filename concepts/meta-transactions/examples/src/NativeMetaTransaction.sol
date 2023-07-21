// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice Контракт токена ERC-20, который поддерживает возможность использовать метатранзакции для владельца токенов
 * @dev Контракт создан в учебных целях. Не использовать на реальных проектах
 */
contract NativeMetaTransaction is ERC20 {
    bytes32 public constant META_TRANSACTION_TYPEHASH =
        keccak256("MetaTransaction(uint256 nonce,address signer,bytes functionSignature)");

    /// Счетчик уникальности подписи пользователя.
    /// Говорит о том, что подпись может быть использована только один раз.
    /// Увеличивается после удачного использования подписи
    mapping(address signer => uint256 nonce) private _nonces;

    struct MetaTransaction {
        uint256 nonce;
        address signer;
        bytes functionSignature;
    }

    event MetaTransactionExecuted(
        address signer,
        address relayer,
        bytes functionSignature
    );

    error ZeroAddress();
    error InvalidSignature();
    error InvalidCall();

    constructor() ERC20("MetaTransactionToken", "MTT") {}

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

    /**
     * @notice Стандартная функция mint
     * @dev В рамках данного не имеет значения. Нужна для выдачи токенов пользователям при тестировании
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Выполнение метатранзакции
     * @param signer Адрес для кого выполняется метатранзакция
     * @param functionSignature Сигнатура функции, которую необходимо выполнить
     * @param v Данные подписи
     * @param r Данные подписи
     * @param s Данные подписи
     */
    function executeMetaTransaction(
        address signer,
        bytes memory functionSignature,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (bytes memory result) {
        MetaTransaction memory _tx = MetaTransaction({
            nonce: _nonces[signer],
            signer: signer,
            functionSignature: functionSignature
        });

        /// Проверяем валидность подписи. Действительно signer разрешал выполнение метатранзакции
        bool isVerify = _verify(signer, _tx, v, r, s);
        if (!isVerify) {
            revert InvalidSignature();
        }

        /// Считаем подпись signer использованной
        _nonces[signer] += 1;

        /// Выполняем метатранзакцию. В конец вызова добавляем адрес аккаунта для кого вызывается транзакция
        /// Этот адрес будет использован в функции _msgSender() для симуляции вызова от настоящего адреса, а не от relayer
        (bool success, bytes memory data) = address(this).call(
            abi.encodePacked(functionSignature, signer)
        );

        if (!success) {
            revert InvalidCall();
        }

        emit MetaTransactionExecuted(signer, msg.sender, functionSignature);

        return data;
    }

    function getNonce(address account) external view returns (uint256) {
        return _nonces[account];
    }

    /// Переопределяет определения адреса, который вызвал транзакцию
    function _msgSender() internal view override returns (address sender) {
        /// Если адрес вызывающего равняется текущему контракту, значит был вызов через метатранзакции
        if (msg.sender == address(this)) {
            assembly {
                /// Достаем адрес пользователя и подставляем его за место relayer адреса,
                /// который вызывал транзакцию и оплачивал газ
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
        else {
            /// Подразумеваем, что вызов от обычного пользователя
            return super._msgSender();
        }
    }

    function _verify(
        address signer,
        MetaTransaction memory _tx,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view returns (bool) {
        if (signer == address(0)) {
            revert ZeroAddress();
        }

        return signer == ecrecover(_getDigest(_tx), v, r, s);
    }

    function _getDigest(MetaTransaction memory _tx) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        META_TRANSACTION_TYPEHASH,
                        _tx.nonce,
                        _tx.signer,
                        keccak256(_tx.functionSignature)
                    )
                )
            )
        );
    }
}
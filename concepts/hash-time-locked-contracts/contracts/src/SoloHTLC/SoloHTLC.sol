// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

address constant NATIVE_CURRENCY = address(0);
uint64 constant MIN_LOCK_TIME = 1 days;

struct LockOrder {
    address sender;
    address recipient;
    bytes32 secretHash;
    address token;
    uint256 value;
    uint64 expiredTime;
}

/**
 * @title Hash time locked contract
 * @notice Смарт-контракт создан в учебных целях для демонстрации работы HTLC
 * @dev Пользователь блокирует активы в момент создания контракта, указав хеш секретной фразы.
 * Зная секретную фразу другой пользователь сможет разблокировать активы.
 * Если этого не происходит первый пользователь может вернуть активы обратно по истечении времени блокировки
 */
contract SoloHTLC {
    using SafeERC20 for IERC20;

    LockOrder private _lockOrder;

    event Locked(LockOrder lockOrder);
    event Claimed(bytes secret, LockOrder lockOrder);
    event Refunded(LockOrder lockOrder);

    error InsufficientAmount();
    error InvalidSender();
    error InvalidRecipient();
    error InvalidSecretHash();
    error InvalidValue();
    error InvalidExpiredTime();
    error TransferFailed();
    error InvalidSecret();
    error ClaimHasExpired();
    error RefundHasNotExpiredYet();

    modifier validateLock(LockOrder memory lockOrder) {
        if (lockOrder.sender == address(0)) {
            revert InvalidSender();
        }

        if (lockOrder.recipient == address(0)) {
            revert InvalidRecipient();
        }

        if (lockOrder.secretHash == bytes32(0)) {
            revert InvalidSecretHash();
        }

        if (lockOrder.value == 0) {
            revert InvalidValue();
        }

        if (lockOrder.expiredTime < block.timestamp + MIN_LOCK_TIME) {
            revert InvalidExpiredTime();
        }

        _;
    }

    modifier validateClaim(bytes memory secret) {
        if (keccak256(abi.encodePacked(secret)) != _lockOrder.secretHash) {
            revert InvalidSecret();
        }

        if (msg.sender != _lockOrder.recipient) {
            revert InvalidRecipient();
        }

        if (_lockOrder.expiredTime <= uint64(block.timestamp)) {
            revert ClaimHasExpired();
        }

        _;
    }

    modifier validateRefund() {
        if (msg.sender != _lockOrder.sender) {
            revert InvalidSender();
        }

        if (_lockOrder.expiredTime > uint64(block.timestamp)) {
            revert RefundHasNotExpiredYet();
        }

        _;
    }

    /**
     * @notice Конструктор. На момент инициализации контракта блокирует активы пользователя
     * @param lockOrder Информация о блокируемых активах
     */
    constructor(LockOrder memory lockOrder) validateLock(lockOrder) payable {
        _lockOrder = lockOrder;

        _transferFrom(lockOrder.token, lockOrder.sender, address(this), lockOrder.value);

        emit Locked(lockOrder);
    }

    /**
     * @notice Позволяет забрать средства получателю актива
     * @param secret Секретная фраза, которую необходимо знать, для того, чтобы разблокировать активы
     */
    function claim(bytes memory secret) external validateClaim(secret) {
        _transfer(_lockOrder.token, _lockOrder.recipient, _lockOrder.value);

        emit Claimed(secret, _lockOrder);
    }

    /**
     * @notice Позволяет забрать средства создателю заблокированных активов
     * @dev Доступно только после наступления expiredTime
     */
    function refund() external validateRefund {
        _transfer(_lockOrder.token, _lockOrder.sender, _lockOrder.value);

        emit Refunded(_lockOrder);
    }

    /// @notice Получить информацию о заблокированных активах
    function getLockOrder() external view returns (LockOrder memory) {
        return _lockOrder;
    }

    function _transfer(address token, address to, uint256 value) private {
        if (token == NATIVE_CURRENCY) {
            (bool success,) = to.call{value: value}("");
            if (!success) {
                revert TransferFailed();
            }
        }
        else {
            IERC20(token).safeTransfer(to, value);
        }
    }

    function _transferFrom(address token, address from, address to, uint256 value) private {
        if (token == NATIVE_CURRENCY) {
            if (msg.value != value) {
                revert InsufficientAmount();
            }
        }
        else {
            IERC20(token).safeTransferFrom(from, to, value);
        }
    }
}

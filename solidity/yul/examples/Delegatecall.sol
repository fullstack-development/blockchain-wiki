// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

/**
 * @notice Смарт-контракт для демонстрации вызова одного смарт-контракта из другого
 * с помощью инструкций inline assembly.
 * @dev Сначала деплоится контракт Implementation
 * Затем деплоится контракт Proxy
 * В calldata контракта прокси передаем закодированный вызов функции increment() с каким-то аргументом
 * Если используете Remix, то передаем их в low level iterations
 * Например вот такие данные: 0x7cf5dab0000000000000000000000000000000000000000000000000000000000000002a
 * Смотрим в отладчике что происходит в этой транзакции
 */
contract Implementation {
    uint256 public sum;

    function increment(uint256 amount) external returns (uint256) {
        require(amount > 0, "Amount is zero");

        sum += amount;
        return sum;
    }
}

contract Proxy {
    uint256 public sum;
    address private immutable _implementation;

    constructor(address implementation) {
        _implementation = implementation;
    }

    fallback() external {
        _delegatecall(_implementation);
    }

    function _delegatecall(address impl) private {
        assembly {
            // берем все что было передано с msg.data (начиная с позиции 0)
            // копируем эти данные в memory тоже начиная с 0 позиции
            calldatacopy(0, 0, calldatasize())

            // делаем вызов имплементации и передаем ей все данные msg.data (начиная с позиции 0)
            // размер возвращаемых данных указываем 0, так как предполагается,
            // что мы не знаем точный размер данных которые вернутся
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // так как на предыдущем шаге мы указали 0 в возвращаемых данных
            // копируем их в memory вручную (также с позиции 0 returndata в позицию 0 memory)
            returndatacopy(0, 0, returndatasize())

            // проверяем была ли выполнена транзакция
            switch result
            case 0 {
                // если нет, откатываем транзакцию и возвращаем данные об ошибке
                // если они вернулись из вызова
                revert(0, returndatasize())
            }
            default {
                // если все хорошо, возвращаем все что получили из вызова
                return(0, returndatasize())
            }
        }
    }
}

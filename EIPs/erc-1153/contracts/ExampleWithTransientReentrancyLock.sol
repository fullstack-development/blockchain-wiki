// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/** 
 * 
 *  _____  _____   _____   _____  _                 __  __  ______  _____  
 * |  __ \|_   _| / ____| / ____|| |         /\    |  \/  ||  ____||  __ \ 
 * | |  | | | |  | (___  | |     | |        /  \   | \  / || |__   | |__) |
 * | |  | | | |   \___ \ | |     | |       / /\ \  | |\/| ||  __|  |  _  / 
 * | |__| |_| |_  ____) || |____ | |____  / ____ \ | |  | || |____ | | \ \ 
 * |_____/|_____||_____/  \_____||______|/_/    \_\|_|  |_||______||_|  \_\
 * 
 * @notice Код написан для демонстрации возможностей transient storage,
 * используется исключительно в этих целях и не проходил аудит
 * Не использовать в mainnet с реальными средствами!
 * 
 */
contract ExampleWithTransientReentrancyLock {
    // Заводим константное значение для адресации в transient storage
    bytes32 constant REENTRANCY_GUARD = keccak256("REENTRANCY_GUARD");

    mapping(address account => uint256 amount) private _balances;

    error InsufficientBalance();
    error ReentrancyAttackPrevented();
    error TransferFailed();

    modifier nonReentrant() {
        // Перед выполнением функции проверяем, что это не повторный вход
        if (_tload(REENTRANCY_GUARD) == 1) {
            revert ReentrancyAttackPrevented();
        }
        // Записываем по ключу REENTRANCY_GUARD значение 1
        _tstore(REENTRANCY_GUARD, 1);

        _;

        // Очищаем значение ключа в transient storage после внешнего вызова
        _tstore(REENTRANCY_GUARD, 0);
    }

    function withdraw(uint256 amount) external nonReentrant {
        // Проверяем текущее состояние
        if (_balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        // Изменяем состояние
        _balances[msg.sender] -= amount;

        // Переводим запрошенные средства
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /// @notice Вспомогательная функция для записи в transient storage
    function _tstore(bytes32 location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    /// @notice Вспомогательная функция для чтения из transient storage
    function _tload(bytes32 location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    receive() external payable {
        _balances[msg.sender] += msg.value;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
contract ExampleWithReentrancyGuard is ReentrancyGuard {
    mapping(address account => uint256 amount) private _balances;

    error InsufficientBalance();
    error ReentrancyAttackPrevented();
    error TransferFailed();

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

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    receive() external payable {
        _balances[msg.sender] += msg.value;
    }
}

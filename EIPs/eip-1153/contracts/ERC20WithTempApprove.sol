// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * 
 * ///////////////////////////////////////////////////////////////
 *                            ВАЖНО!
 * ///////////////////////////////////////////////////////////////
 * 
 * @notice Код написан для демонстрации возможностей transient storage,
 * используется исключительно в этих целях и не проходил аудит
 * Не использовать в mainnet с реальными средствами!
 *
 */
contract ERC20WithTempApprove is ERC20 {
    error ExternalCallFailed();

    constructor() ERC20("Test", "T") {}

    /// @notice Функция для вызова внешнего смарт-контракта с выдачей ему разрешения на списание токенов
    function approveAndCall(address spender, uint256 value, bytes memory data) external {
        // Выдаем временный апрув только на ту сумму которую планируем потратить
        _temporaryApprove(spender, value);

        // Выполняем внешний вызов к смарт-контракту который спишет токены
        (bool success,) = address(spender).call(data);
        if (!success) {
            revert ExternalCallFailed();
        }
    }

    /// @notice Функция для выдачи временного разрешения
    function _temporaryApprove(address spender, uint256 value) private {
        // Формируем ключ для записи в transient storage
        // записываем в него адрес владельца токенов,
        // адрес контракта, который их спишет
        // и само значение
        bytes32 key = keccak256(abi.encode(msg.sender, spender, value));

        // Записываем одобренное количество токенов по сформированному ключу
        assembly {
            tstore(key, value)
        }
    }

    /**
     * @notice Когда целевой смарт-контракт вызовет transferFrom
     * transferFrom задействует функцию _spendAllowance
     * поэтому здесь мы проверим было ли выдано временное разрешение
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal override {
        // для начала восстановим ключ
        bytes32 key = keccak256(abi.encode(owner, spender, value));
        
        // Получаем значение по ключу
        uint256 temporaryApproval;
        assembly {
            temporaryApproval := tload(key)
        }

        // Если одобрение есть, перевод токенов будет выполнен
        // если нет, передаем выполнение стандартной функции
        // для проверки ранее выданных разрешений
        if (temporaryApproval > 0) {
            // Проверка соответствует ли временное разрешение тому value
            // которое будет потрачено - не имеет смысла
            // потому что в таком случае ключ не совпадет

            // Обязательно очищаем переходное хранилище!
            assembly {
                tstore(key, 0)
            }
        } else {
            super._spendAllowance(owner, spender, value);
        }
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

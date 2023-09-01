// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice Пример из раздела Events
 */

contract EmitEvent {
    event SomeLog(uint256 indexed a, uint256 indexed b, bool c);

    function emitEvent() external {
        assembly {
            // Хеш собтия - keccak256("SomeLog(uint256,uint256,bool)")
            let signature := 0x39cf0823186c1f89c8975545aebaa16813bfc9511610e72d8cff59da81b23c72

            // получаем указатель на свободную память
            let ptr := mload(0x40)

            // записываем число 1 по этому адресу (0x80)
            mstore(ptr, 1)

            // создаем событие SomeLog(2, 3, true)
            log3(0x80, 0x20, signature, 2, 3)
        }
    }
}
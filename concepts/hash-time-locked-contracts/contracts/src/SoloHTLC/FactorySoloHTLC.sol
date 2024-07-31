// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SoloHTLC, LockOrder, NATIVE_CURRENCY} from "./SoloHTLC.sol";

/**
 * @title Фабрика для hash time locked контрактов
 * @notice Смарт-контракт создан в учебных целях для демонстрации создания HTLC
 * @dev Является точкой входа для пользователя. Вызывает функцию createHTLC().
 * После этого для него создается отдельный смарт-контракт HTLC на котором в момент создания блокируются активы
 * Для блокировки ERC-20 токенов, перед созданием HTLC необходимо дать approve().
 */
contract FactorySoloHTLC {
    event HTLCCreated(address indexed creator, address htlc);

    /**
     * @notice Создание hash time locked контракта
     * @param lockOrder Информация о блокируемых активах
     * @param salt Используется для создания контракта через create2 opcode
     */
    function createHTLC(LockOrder memory lockOrder, uint256 salt) external payable returns (address htlcAddress) {
        bytes memory bytecode = abi.encodePacked(type(SoloHTLC).creationCode, abi.encode(lockOrder));
        htlcAddress = getHTLCAddress(bytecode, salt);

        assembly {
            // create(v, p, n)
            // v = amount of ETH to send
            // p = pointer in memory to start of code
            // n = size of code
            htlcAddress := create2(callvalue(), add(bytecode, 0x20), mload(bytecode), salt)

            if iszero(extcodesize(htlcAddress)) { revert(0, 0) }
        }

        emit HTLCCreated(msg.sender, htlcAddress);
    }

    /**
     * @notice Возвращает будущий адрес контракта HTLC
     * @param bytecode Байт-код смарт-контракта HTLC
     * @param salt Случайное число для создания контракта через create2
     */
    function getHTLCAddress(bytes memory bytecode, uint256 salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}
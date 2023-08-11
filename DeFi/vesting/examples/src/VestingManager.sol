// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IVestingToken, Vesting} from "./IVestingToken.sol";

/**
 * @title Контракт-фабрика для создания share-токенов
 * @notice Основная задача смарт-контракта создавать экземпляры share-токенов
 * и устанавливать на них расписание вестинга
 * @dev Код предоставлен исключительно в ознакомительных целях и не протестирован
 * Из контракта убрано все лишнее, включая некоторые проверки, геттеры/сеттеры и события
 */
contract VestingManager {
    address private _vestingImplementation;

    constructor(address implementation) {
        _vestingImplementation = implementation;
    }

    /**
     * @notice Основная функция для создания экземпляра share-токена
     * Т.к. это создание ERC20 - задаем name и symbol
     * Указываем адрес токена который будет блокироваться под вестинг
     * Указываем адрес который сможет минтить share-токены (к примеру контракт продаж)
     * Передаем расписание
     */
    function createVesting(
        string calldata name,
        string calldata symbol,
        address baseToken,
        address minter,
        Vesting calldata vesting
    ) external returns (address vestingToken) {
        vestingToken = _createVestingToken(name, symbol, minter, baseToken);

        IVestingToken(vestingToken).setVestingSchedule(
            vesting.startTime,
            vesting.cliff,
            vesting.schedule
        );
    }

    function _createVestingToken(
        string calldata name,
        string calldata symbol,
        address minter,
        address baseToken
    ) private returns (address vestingToken) {
        vestingToken = Clones.clone(_vestingImplementation);

        IVestingToken(vestingToken).initialize(name, symbol, minter, baseToken);
    }
}

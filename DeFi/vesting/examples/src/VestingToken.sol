// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@oz-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {Vesting, Schedule} from "./IVestingToken.sol";

/**
 * @title Контракт share-токена (вестинг-токен)
 * @notice Отвечает за логику блокировки/разблокировки средств
 * @dev Код предоставлен исключительно в ознакомительных целях и не протестирован
 * Из контракта убрано все лишнее, включая некоторые проверки, геттеры/сеттеры и события
 */
contract VestingToken is Initializable, ERC20Upgradeable {
    using SafeERC20 for IERC20;

    uint256 private constant BASIS_POINTS = 10_000;

    address private _minter;
    address private _vestingManager;
    IERC20 private _baseToken;
    Vesting private _vesting;
    uint256 private _initialLockedSupply;

    constructor() {
        _disableInitializers();
    }

    mapping(address => uint256) private _initialLocked;
    mapping(address => uint256) private _released;

    // region - Errors

    /////////////////////
    //      Errors     //
    /////////////////////

    error OnlyMinter();
    error OnlyVestingManager();
    error NotEnoughTokensToClaim();
    error StartTimeAlreadyElapsed();
    error CliffBeforeStartTime();
    error IncorrectSchedulePortions();
    error IncorrectScheduleTime(uint256 incorrectTime);
    error TransfersNotAllowed();
    error MintingAfterCliffIsForbidden();

    // endregion

    // region - Modifiers

    modifier onlyMinter() {
        if (msg.sender != _minter) {
            revert OnlyMinter();
        }

        _;
    }

    modifier onlyVestingManager() {
        if (msg.sender != _vestingManager) {
            revert OnlyVestingManager();
        }

        _;
    }

    // endregion

    // region - Initialize

    /**
     * @notice Так как это прокси, нужно выполнить инициализацию
     * @dev Создается и инициализируется только контрактом VestingManager
     */
    function initialize(string calldata name, string calldata symbol, address minter, address baseToken)
        public
        initializer
    {
        __ERC20_init(name, symbol);

        _minter = minter;
        _baseToken = IERC20(baseToken);
        _vestingManager = msg.sender;
    }

    // endregion

    // region - Set vesting schedule

    /**
     * @notice Установка расписания также выполняется контрактом VestingManager
     * @dev Здесь важно проверить что расписание было передано корректное
     */
    function setVestingSchedule(uint256 startTime, uint256 cliff, Schedule[] calldata schedule)
        external
        onlyVestingManager
    {
        uint256 scheduleLength = schedule.length;

        _checkVestingSchedule(startTime, cliff, schedule, scheduleLength);

        _vesting.startTime = startTime;
        _vesting.cliff = cliff;

        for (uint256 i = 0; i < scheduleLength; i++) {
            _vesting.schedule.push(schedule[i]);
        }
    }

    function _checkVestingSchedule(
        uint256 startTime,
        uint256 cliff,
        Schedule[] calldata schedule,
        uint256 scheduleLength
    ) private view {
        if (startTime < block.timestamp) {
            revert StartTimeAlreadyElapsed();
        }

        if (startTime > cliff) {
            revert CliffBeforeStartTime();
        }

        uint256 totalPercent;

        for (uint256 i = 0; i < scheduleLength; i++) {
            totalPercent += schedule[i].portion;

            bool isEndTimeOutOfOrder = (i != 0) && schedule[i - 1].endTime >= schedule[i].endTime;

            if (cliff >= schedule[i].endTime || isEndTimeOutOfOrder) {
                revert IncorrectScheduleTime(schedule[i].endTime);
            }
        }

        if (totalPercent != BASIS_POINTS) {
            revert IncorrectSchedulePortions();
        }
    }

    // endregion

    // region - Mint

    /**
     * @notice Списываем токен который будем блокировать и минтим share-токен
     */
    function mint(address to, uint256 amount) external onlyMinter {
        if (block.timestamp >= _vesting.cliff) {
            revert MintingAfterCliffIsForbidden();
        }

        _baseToken.safeTransferFrom(msg.sender, address(this), amount);

        _mint(to, amount);

        _initialLocked[to] += amount;
        _initialLockedSupply += amount;
    }

    // endregion

    // region - Claim

    /**
     * @notice Сжигаем share-токен и переводим бенефициару разблокированные базовые токены
     */
    function claim() external {
        uint256 releasable = availableBalanceOf(msg.sender);

        if (releasable == 0) {
            revert NotEnoughTokensToClaim();
        }

        _released[msg.sender] += releasable;

        _burn(msg.sender, releasable);
        _baseToken.safeTransfer(msg.sender, releasable);
    }

    // endregion

    // region - Vesting getters

    function getVestingSchedule() public view returns (Vesting memory) {
        return _vesting;
    }

    function unlockedSupply() external view returns (uint256) {
        return _totalUnlocked();
    }

    function lockedSupply() external view returns (uint256) {
        return _initialLockedSupply - _totalUnlocked();
    }

    function availableBalanceOf(address account) public view returns (uint256 releasable) {
        releasable = _unlockedOf(account) - _released[account];
    }

    // endregion

    // region - Private functions

    function _unlockedOf(address account) private view returns (uint256) {
        return _computeUnlocked(_initialLocked[account], block.timestamp);
    }

    function _totalUnlocked() private view returns (uint256) {
        return _computeUnlocked(_initialLockedSupply, block.timestamp);
    }

    /**
     * @notice Основная функция для расчета разблокированных токенов
     * @dev Проверяется сколько прошло полных периодов и сколько времени прошло
     * после последнего полного периода.
     */
    function _computeUnlocked(uint256 lockedTokens, uint256 time) private view returns (uint256 unlockedTokens) {
        if (time < _vesting.cliff) {
            return 0;
        }

        uint256 currentPeriodStart = _vesting.cliff;
        Schedule[] memory schedule = _vesting.schedule;
        uint256 scheduleLength = schedule.length;

        for (uint256 i = 0; i < scheduleLength; i++) {
            Schedule memory currentPeriod = schedule[i];
            uint256 currentPeriodEnd = currentPeriod.endTime;
            uint256 currentPeriodPortion = currentPeriod.portion;

            if (time < currentPeriodEnd) {
                uint256 elapsedPeriodTime = time - currentPeriodStart;
                uint256 periodDuration = currentPeriodEnd - currentPeriodStart;

                unlockedTokens +=
                    (lockedTokens * elapsedPeriodTime * currentPeriodPortion) / (periodDuration * BASIS_POINTS);
                break;
            } else {
                unlockedTokens += (lockedTokens * currentPeriodPortion) / BASIS_POINTS;
                currentPeriodStart = currentPeriodEnd;
            }
        }
    }

    /**
     * @notice Трансферить токены нельзя, только минтить и сжигать
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0) && to != address(0)) {
            revert TransfersNotAllowed();
        }
    }

    // endregion
}

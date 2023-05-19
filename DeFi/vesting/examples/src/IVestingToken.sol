// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

struct Schedule {
    uint256 endTime;
    uint256 portion;
}

struct Vesting {
    uint256 startTime;
    uint256 cliff;
    Schedule[] schedule;
}

interface IVestingToken {
    function initialize(
        string calldata name,
        string calldata symbol,
        address minter,
        address token
    ) external;

    function setVestingSchedule(
        uint256 startTime,
        uint256 cliff,
        Schedule[] calldata schedule
    ) external;

    function mint(address to, uint256 amount) external;

    function getVestingSchedule() external view returns (Vesting memory);
}

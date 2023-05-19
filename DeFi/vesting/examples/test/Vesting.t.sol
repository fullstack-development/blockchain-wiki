// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {IVestingToken, Vesting, Schedule} from "../src/IVestingToken.sol";
import "../src/VestingManager.sol";
import "../src/VestingToken.sol";

contract VestingTest is Test {
    ERC20Mock internal _baseToken;
    VestingManager internal _vestingManager;
    VestingToken internal _vestingTokenImpl;
    VestingToken internal _vestingToken;

    address internal ALICE = vm.addr(0xA11CE);

    function setUp() public {
        _baseToken = new ERC20Mock();

        _vestingTokenImpl = new VestingToken();
        _vestingManager = new VestingManager(address(_vestingTokenImpl));
    }

    function test_createVestingToken() public {
        Schedule[] memory schedule = new Schedule[](1);
        Schedule memory scheduleItem = Schedule(block.timestamp + 1 days, 10000);
        schedule[0] = scheduleItem;

        string memory name = "VestingToken";
        string memory symbol = "VT";
        address minter = address(this);
        uint256 startTime = block.timestamp;
        uint256 cliff = startTime;
        Vesting memory vestingParams = Vesting(startTime, cliff, schedule);

        address vestingToken = _vestingManager.createVesting(name, symbol, address(_baseToken), minter, vestingParams);

        assertEq(VestingToken(vestingToken).name(), name);
        assertEq(VestingToken(vestingToken).symbol(), symbol);
        assertEq(VestingToken(vestingToken).getVestingSchedule().startTime, startTime);
        assertEq(VestingToken(vestingToken).getVestingSchedule().cliff, cliff);
    }

    function test_mintVestingTokens() public {
        Schedule[] memory schedule = new Schedule[](1);
        Schedule memory scheduleItem = Schedule(block.timestamp + 2 days, 10000);
        schedule[0] = scheduleItem;

        Vesting memory vestingParams = Vesting(block.timestamp, block.timestamp + 1 days, schedule);

        address vestingToken =
            _vestingManager.createVesting("VestingToken", "VT", address(_baseToken), address(this), vestingParams);

        uint256 vestingValue = 1e18;
        _baseToken.mint(address(this), vestingValue);
        _baseToken.approve(vestingToken, vestingValue);

        VestingToken(vestingToken).mint(ALICE, vestingValue);

        assertEq(VestingToken(vestingToken).balanceOf(ALICE), vestingValue);
    }

    function test_claimBaseTokens() public {
        Schedule[] memory schedule = new Schedule[](1);
        Schedule memory scheduleItem = Schedule(block.timestamp + 2 days, 10000);
        schedule[0] = scheduleItem;

        Vesting memory vestingParams = Vesting(block.timestamp, block.timestamp + 1 days, schedule);

        address vestingToken =
            _vestingManager.createVesting("VestingToken", "VT", address(_baseToken), address(this), vestingParams);

        uint256 vestingValue = 1e18;
        _baseToken.mint(address(this), vestingValue);
        _baseToken.approve(vestingToken, vestingValue);

        VestingToken(vestingToken).mint(ALICE, vestingValue);

        vm.warp(block.timestamp + 2 days);
        assertEq(VestingToken(vestingToken).availableBalanceOf(ALICE), vestingValue);
        assertEq(_baseToken.balanceOf(ALICE), 0);

        vm.prank(ALICE);
        VestingToken(vestingToken).claim();
        
        assertEq(_baseToken.balanceOf(ALICE), vestingValue);
        assertEq(VestingToken(vestingToken).balanceOf(ALICE), 0);
        assertEq(VestingToken(vestingToken).availableBalanceOf(ALICE), 0);
    }
}

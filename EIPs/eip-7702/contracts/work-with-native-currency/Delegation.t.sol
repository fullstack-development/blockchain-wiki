// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console, Vm, StdCheats} from "forge-std/Test.sol";
import {Delegation, Target} from "./Delegation.sol";

contract DelegationTest is Test {
    Delegation public delegation;
    Target public target;

    StdCheats.Account public user;
    StdCheats.Account public operator;

    function setUp() external {
        delegation = new Delegation();
        target = new Target();

        user = makeAccount("User");
        operator = makeAccount("Operator");
    }

    function test_workWithNativeCurrency_buy(uint256 value) external {
        deal(operator.addr, value);

        vm.startBroadcast(operator.key);
        vm.signAndAttachDelegation(address(delegation), user.key);
        vm.stopBroadcast();

        vm.prank(operator.addr);
        Delegation(user.addr).buy{value: value}();

        // Нативная валюта остается на балансе пользователя
        assertEq(user.addr.balance, value);
    }

    function test_workWithNativeCurrency_buyAndSendToTarget(uint256 value) external {
        deal(operator.addr, value);

        vm.startBroadcast(operator.key);
        vm.signAndAttachDelegation(address(delegation), user.key);
        vm.stopBroadcast();

        vm.prank(operator.addr);
        Delegation(user.addr).buyAndSendToTarget{value: value}(address(target));

        // Нативная валюта остается на балансе target смарт-контракта
        assertEq(address(target).balance, value);
    }
}
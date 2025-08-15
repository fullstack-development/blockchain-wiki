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
        target = new Target();
        delegation = new Delegation();

        user = makeAccount("User");
        operator = makeAccount("Operator");

        vm.label(address(delegation), "Delegation");
        vm.label(address(this), "address(this)");
        vm.label(address(target), "Target");
        vm.label(user.addr, "User");
        vm.label(operator.addr, "Operator");
    }

    function test_checkCondition(uint256 value) external {
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

        // Симулируем, что пользователь напрямую вызывает целевой контракт и транзакция ревертится
        vm.expectRevert(Target.EOACallIsNotAllowed.selector);
        vm.prank(user.addr, user.addr);
        target.setValue(value);

        // Operator прикрепляет смарт-контракт Delegation к user
        vm.startBroadcast(operator.key);
        vm.attachDelegation(signedDelegation);
        vm.stopBroadcast();

        // Operator вызывает функцию setValue на контракте Delegation от имени user,
        // которая установит value на смарт-контракте Target
        vm.prank(operator.addr, operator.addr);
        Delegation(user.addr).setValue(address(target), value);

        // Проверяем, что значение установлено (проверку обошли)
        assertEq(target.getValue(), value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console, Vm, StdCheats} from "forge-std/Test.sol";
import {Delegation} from "./Delegation.sol";

contract DelegationTest is Test {
    uint256 private constant _INITIAL_VALUE = 1;
    Delegation public delegation;

    StdCheats.Account public user;
    StdCheats.Account public operator;

    function setUp() external {
        delegation = new Delegation(_INITIAL_VALUE);

        user = makeAccount("User");
        operator = makeAccount("Operator");
    }

    function test_workWithStorage(uint256 value) external {
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

        vm.startBroadcast(operator.key);
        vm.attachDelegation(signedDelegation);
        vm.stopBroadcast();

        // Step 1. Проверяем, что хранилище user пустое

        // Вызов getValue через user вернет 0, так как хранилище user пустое
        assertEq(Delegation(user.addr).getValue(), 0);
        // Вызов getValue через delegation вернет _INITIAL_VALUE, так как хранилище delegation не изменилось и было установлено через конструктор при деплое
        assertEq(delegation.getValue(), _INITIAL_VALUE);

        // Step 2. Устанавливаем значение в хранилище user
        Delegation(user.addr).setValue(value);

        // Вызов getValue через user вернет установленное value
        assertEq(Delegation(user.addr).getValue(), value);
        //Вызов getValue через delegation вернет _INITIAL_VALUE, хранилище не изменилось
        assertEq(delegation.getValue(), _INITIAL_VALUE);
    }
}

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

    function test_attachCode() external {
        // Проверяем наличие кода у EOA
        console.logBytes(user.addr.code); // 0x

        // Симулируем подписание транзакции на прикрепление кода пользователем
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

        vm.startBroadcast(operator.key);

        // Отправляем транзакцию на прикрепление кода к user. Обратить внимание, что это делает operator, а не user
        vm.attachDelegation(signedDelegation);

        vm.stopBroadcast();

        console.logBytes(user.addr.code); // 0xef01005615deb798bb3e4dfa0139dfa1b3d433cc23b72f
    }
}
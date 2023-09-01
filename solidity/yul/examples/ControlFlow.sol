// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/**
 * @notice В смарт-контракте отображены шаблоны управления потоком выполнения в Yul
 */
contract ControlFlow {
    function ifStatement(uint256 n) external {
        assembly {
            if iszero(n) {
                // если true, выполнить действие
            }
        }
    }

    function switchStatement(uint256 n) external {
        assembly {
            switch n
            case 0 {
                // если n == 0 выполнить действие
            }
            case 1 {
                // если n == 1 выполнить действие
            }
            default {
                // если ни один вариант не сработал
                // выполнить действие по умолчанию
            }
        }
    }

    function forLoop(uint256 n) external {
        assembly {
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // выполнить действие
            }
        }
    }

    function forLoopWithAnotherCondition(uint256 n) external {
        assembly {
            let i := 0
            for {} lt(i, n) {} {
                // выполнить действие
                i := add(i, 1)
            }
        }
    }
}

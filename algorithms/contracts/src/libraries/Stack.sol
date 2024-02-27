// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Стек
 * @notice Библиотека для реализации структуры данных стек
 * @dev Использовать можно следующим образом:
 * using Stack for bytes[];
 * bytes[] private _stack;
 */
library Stack {
    /**
     * @notice Добавить элемент в стек
     * @param stack Массив, который реализует структуру стек
     * @param data Элемент для добавления в стек
     */
    function pushTo(bytes[] storage stack, bytes calldata data) external {
        stack.push(data);
    }

    /**
     * @notice Извлечь элемент из стека
     * @param stack Массив, который реализует структуру стек
     * @return data Последний элемент в стеке
     */
    function popOut(bytes[] storage stack) external returns (bytes memory data) {
        data = stack[stack.length - 1];
        stack.pop();
    }
}
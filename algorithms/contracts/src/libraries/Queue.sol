// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Очередь
 * @notice Библиотека для реализации структуры данных очереди
 * @dev Использовать можно следующим образом:
 * using Queue for Queue.Info;
 * Queue.Info private _queue;
 */
library Queue {
    struct Info {
        uint256 first;
        uint256 last;
        mapping(uint256 => string) items;
    }

    error ZeroQueue();

    /**
     * @notice Добавить элемент в очередь
     * @param queue Хранилище очереди, представлено структурой Info
     * @param item Элемент для добавления в очередь
     */
    function enqueue(Info storage queue, string calldata item) external {
        queue.last += 1;

        queue.items[queue.last] = item;
    }

    /**
     * @notice Извлечь элемент из очереди
     * @param queue Хранилище очереди, представлено структурой Info
     * @return item Первый элемент в очереди
     */
    function dequeue(Info storage queue) external returns (string memory item) {
        uint256 first = queue.first;
        uint256 last = queue.last;

        if (last <= first) {
            revert ZeroQueue();
        }

        item = queue.items[first + 1];

        delete queue.items[first + 1];
        queue.first += 1;
    }

    /**
     * @notice Количество элементов в очереди
     * @param queue Хранилище очереди, представлено структурой Info
     */
    function length(Info storage queue) external view returns (uint256) {
        return queue.last - queue.first;
    }
}
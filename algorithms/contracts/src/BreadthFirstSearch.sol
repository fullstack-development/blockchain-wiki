// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Поиск в ширину
 * @notice Контракт реализует функцию search(),
 * которая выполняет поиск в ширину
 * @dev Для организации поиска необходимо создать граф.
 * Функция addNode() - создает узлы графа.
 * Функция addEdge() - создает ребра графа(связи между узлами графа)
 * Важно! Все узлы графа нумеруются в порядке добавления.
 * Это необходимо, чтобы знать общее количество узлов для проведения поиска и учета посещенных узлов
 */
contract BreadthFirstSearch {
    using Counters for Counters.Counter;

    struct Node {
        string name;
        uint256[] neighbors;
    }

    mapping(uint256 => Node) private _graph;
    Counters.Counter private _nodeCount;

    /**
     * @notice Создает узлы графа
     * @param name Название узла
     */
    function addNode(string memory name) external {
        Node storage newNode = _graph[_nodeCount.current()];
        newNode.name = name;

        _nodeCount.increment();
    }

    /**
     * @notice Добавляет связь между узлами графа
     * @param from Начальный узел графа
     * @param to Конечный узел графа
     */
    function addEdge(uint256 from, uint256 to) external {
        _graph[from].neighbors.push(to);
    }

    /**
     * @notice Вызывает алгоритм поиска в ширину
     * @param start Идентификатор узла с которого начнется поиск
     * @param goal Искомый идентификатор узла
     * @dev По сути функция проверит возможность добраться из одной узла графа в другой
     */
    function search(uint256 start, uint256 goal) external view returns (bool) {
        /// Массив для учета посещенных узлов. Это поможет избежать зацикливания
        bool[] memory visited = new bool[](_nodeCount.current());

        /// Массив для организации очереди поиска.
        /// Проверяя каждый узел мы будем добавлять связи этого узла в конец очереди для последующей проверки
        uint256[] memory queue = new uint256[](_nodeCount.current());

        /// Счетчики для навигации по массиву очереди. Будут помогать добавлять узлы в очередь и извлекать из очереди
        uint256 front = 0;
        uint256 back = 0;

        /// Помещаем в очередь начальный элемент
        queue[back++] = start;

        /// Помечаем узел проверенным
        visited[start] = true;

        while (front != back) {
            uint256 current = queue[front++];

            if (current == goal) {
                /// Если целевое значение равно значению узла графа, то значение найдено
                return true;
            }

            /// Извлекаем все соседние узлы рассматриваемого узла графа
            uint256[] memory neighbors = _graph[current].neighbors;

            for (uint256 i = 0; i < neighbors.length; ++i) {
                uint256 neighbor = neighbors[i];

                if (!visited[neighbor]) {
                    /// Помечаем соседний узел, как проверенный
                    visited[neighbor] = true;

                    /// Добавляем соседний узел в очередь
                    queue[back++] = neighbor;
                }
            }
        }

        return false;
    }
}

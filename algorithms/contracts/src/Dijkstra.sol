// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Алгоритм Дейкстры
 * @notice Контракт реализует функцию search(),
 * которая выполняет поиск кратчайшего пути до любой точки графа
 */
contract Dijkstra {
    /**
     * @notice Вызывает алгоритм поиска кратчайшего пути
     * @param graph граф, в котором будет производиться поиск
     * @param startNodeId Идентификатор узла с которого будет начинаться поиск
     * @dev Считаем что все узлы графа пронумерованы от 0 до graph.length
     * Если до узла будет невозможно добраться, то возвращаемое значение будет равняться type(uint256).max
     */
    function search(uint256[][] memory graph, uint256 startNodeId) public pure returns (uint256[] memory) {
        /// Массив для учета минимального расстояние, чтобы добраться до узла
        uint256[] memory nodeWeights = new uint256[](graph.length);
        /// Массив для учета посещенных узлов. Это поможет избежать зацикливания
        bool[] memory visited = new bool[](graph.length);

        /// Проставляем все результирующие значения в максимально возможные.
        /// Это необходимо для поиска минимального пути до каждого узла графа
        for (uint256 i = 0; i < graph.length; i++) {
            nodeWeights[i] = type(uint256).max;
        }

        /// Расстояние из начального узла до начального равняется нулю. Закрепляем это сразу.
        nodeWeights[startNodeId] = 0;

        /// Обходим все узлы графа
        uint256 count = graph.length;
        while(count > 0) {
            /// Находим минимальный путь до ближайшего соседнего узла графа и устанавливаем такой узел начальным
            startNodeId = _findMinWeight(nodeWeights, visited);
            visited[startNodeId] = true;

            /// Считаем все возможные расстояния до ближайших соседних узлов.
            for (uint256 endNodeId = 0; endNodeId < graph.length; endNodeId++) {
                if (
                    !visited[endNodeId]
                    && graph[startNodeId][endNodeId] != 0
                    && nodeWeights[startNodeId] != type(uint256).max
                    && nodeWeights[startNodeId] + graph[startNodeId][endNodeId] < nodeWeights[endNodeId]
                ) {
                    /// Обновляем расстояние, если оно меньше, чем было установлено ранее
                    nodeWeights[endNodeId] = nodeWeights[startNodeId] + graph[startNodeId][endNodeId];
                }
            }

            count--;
        }

        return nodeWeights;
    }

    function _findMinWeight(uint256[] memory nodeWeights, bool[] memory visited)
        private
        pure
        returns (uint256 nodeId)
    {
        uint256 minWeight = type(uint256).max;

        for (uint256 i = 0; i < nodeWeights.length; i++) {
            if (!visited[i] && nodeWeights[i] <= minWeight) {
                minWeight = nodeWeights[i];
                nodeId = i;
            }
        }
    }
}

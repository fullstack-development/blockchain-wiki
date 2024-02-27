// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Dijkstra} from "../src/Dijkstra.sol";

contract DijkstraTest is Test {
    Dijkstra dijkstra;

    function setUp() external {
        dijkstra = new Dijkstra();
    }

    function test_dijkstra_directBond() external {
        uint256 nodeCount = 5;
        uint256 edgeCount = 5;
        uint[][] memory graph = new uint[][](edgeCount);

        for(uint i = 0; i < edgeCount; i++) {
            graph[i] = new uint[](edgeCount);
        }

        graph[0][1] = 2;
        graph[1][2] = 3;
        graph[2][3] = 2;
        graph[3][4] = 1;
        graph[0][4] = 8;

        uint256 startNodeId = 0;
        uint[] memory result = dijkstra.search(graph, startNodeId);
        uint[] memory expected = new uint[](nodeCount);
        expected[0] = 0;
        expected[1] = 2;
        expected[2] = 5;
        expected[3] = 7;
        expected[4] = 8;

        for(uint i = 0; i < nodeCount; i++) {
            assertTrue(result[i] == expected[i]);
        }
    }

    function test_dijkstra_mixedBond() external {
        uint256 nodeCount = 6;
        uint256 edgeCount = 10;
        uint[][] memory graph = new uint[][](edgeCount);

        for(uint i = 0; i < edgeCount; i++) {
            graph[i] = new uint[](edgeCount);
        }

        graph[0][1] = 2;
        graph[1][2] = 1;
        graph[1][3] = 5;
        graph[2][1] = 4;
        graph[2][3] = 3;
        graph[3][4] = 3;
        graph[4][2] = 2;
        graph[4][5] = 5;
        graph[5][0] = 4;
        graph[5][1] = 7;

        uint256 startNodeId = 2;
        uint[] memory result = dijkstra.search(graph, startNodeId);
        uint[] memory expected = new uint[](nodeCount);
        expected[0] = 15;
        expected[1] = 4;
        expected[2] = 0;
        expected[3] = 3;
        expected[4] = 6;
        expected[5] = 11;

        for(uint i = 0; i < nodeCount; i++) {
            assertTrue(result[i] == expected[i]);
        }
    }

    function test_dijkstra_emptyEdge() external {
        uint256 nodeCount = 5;
        uint256 edgeCount = 5;
        uint[][] memory graph = new uint[][](edgeCount);

        for(uint i = 0; i < edgeCount; i++) {
            graph[i] = new uint[](edgeCount);
        }

        graph[0][1] = 2;
        graph[1][2] = 3;
        graph[2][3] = 2;

        uint256 startNodeId = 4;
        uint[] memory result = dijkstra.search(graph, startNodeId);
        uint[] memory expected = new uint[](nodeCount);
        expected[0] = type(uint256).max;
        expected[1] = type(uint256).max;
        expected[2] = type(uint256).max;
        expected[3] = type(uint256).max;
        expected[4] = 0;

        for(uint i = 0; i < nodeCount; i++) {
            assertTrue(result[i] == expected[i]);
        }
    }
}
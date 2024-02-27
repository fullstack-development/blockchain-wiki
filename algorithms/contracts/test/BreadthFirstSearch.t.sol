// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BreadthFirstSearch.sol";

contract BreadthFirstSearchTest is Test {
    BreadthFirstSearch public breadthFirstSearch;

    function setUp() external {
        breadthFirstSearch = new BreadthFirstSearch();

        _createNodes();
        _createEdges();
    }

    function test_search() external {
        assertTrue(breadthFirstSearch.search(0, 4));
        assertTrue(breadthFirstSearch.search(2, 3));
        assertTrue(breadthFirstSearch.search(0, 5));
        assertTrue(breadthFirstSearch.search(1, 7));
        assertTrue(breadthFirstSearch.search(0, 0));
        assertTrue(breadthFirstSearch.search(9, 9));
        assertTrue(breadthFirstSearch.search(3, 3));

        assertFalse(breadthFirstSearch.search(3, 0));
        assertFalse(breadthFirstSearch.search(5, 9));
        assertFalse(breadthFirstSearch.search(1, 0));
        assertFalse(breadthFirstSearch.search(3, 2));
        assertFalse(breadthFirstSearch.search(1, 0));
    }

    /// Схему изображения графа можно найти по пути ../images/breadth-first-search-test-graph.png
    function _createNodes() private {
        // Tomsk => 0
        breadthFirstSearch.addNode("Tomsk");
        // Moscow => 1
        breadthFirstSearch.addNode("Moscow");
        // Anapa => 2
        breadthFirstSearch.addNode("Anapa");
        // Sochi => 3
        breadthFirstSearch.addNode("Sochi");
        // Vladivostok => 4
        breadthFirstSearch.addNode("Vladivostok");
        // Kaliningrad => 5
        breadthFirstSearch.addNode("Kaliningrad");
        // St.Petersburg => 6
        breadthFirstSearch.addNode("St.Petersburg");
        // Yakutsk => 7
        breadthFirstSearch.addNode("Yakutsk");
        // Irkutsk => 8
        breadthFirstSearch.addNode("Irkutsk");
        // Krasnoyarsk => 9
        breadthFirstSearch.addNode("Krasnoyarsk");
    }

    function _createEdges() private {
        // Tomsk => Moscow
        breadthFirstSearch.addEdge(0, 1);
        // Tomsk => Irkutsk
        breadthFirstSearch.addEdge(0, 8);
        // Tomsk => Vladivostok
        breadthFirstSearch.addEdge(0, 4);
        // Tomsk => Krasnoyarsk
        breadthFirstSearch.addEdge(0, 9);

        // Moscow => Irkutsk
        breadthFirstSearch.addEdge(1, 8);
        // Moscow => Anapa
        breadthFirstSearch.addEdge(1, 2);
        // Moscow => Vladivostok
        breadthFirstSearch.addEdge(1, 4);
        // Moscow => St.Petersburg
        breadthFirstSearch.addEdge(1, 6);
        // Moscow => Yakutsk
        breadthFirstSearch.addEdge(1, 7);

        // Anapa => Sochi
        breadthFirstSearch.addEdge(2, 3);

        // Vladivostok => Sochi
        breadthFirstSearch.addEdge(4, 3);

        // St.Petersburg => Kaliningrad
        breadthFirstSearch.addEdge(6, 5);
    }
}


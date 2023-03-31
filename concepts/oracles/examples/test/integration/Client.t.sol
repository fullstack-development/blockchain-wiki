// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";
import "../../src/Oracle.sol";
import "../../src/Client.sol";
import {RequestType} from "../../src/utils/Constants.sol";

contract ClientTest is Test {
    Oracle public oracle;
    Client public client;

    address oracleNode = vm.addr(100);

    event RequestCreated(uint256 indexed requestId, bytes data);
    event RequestExecuted(uint256 requestId);

    function setUp() external {
        oracle = new Oracle();
        client = new Client(address(oracle));

        oracle.setOracleNode(oracleNode);
    }

    function test_getPriceProcess() external {
        uint256 requestId = 1;
        uint256 testPrice = 150e18;
        bytes memory requestData = abi.encode(RequestType.GET_PRICE);
        bytes memory answerData = abi.encode(testPrice);

        assertEq(client.getPrice(), 0);

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(requestId, requestData);

        client.requestPrice(oracleNode);

        vm.expectCall(address(client), 0, abi.encodeWithSelector(Client.setPrice.selector, answerData));

        // simulate call by oracle node
        vm.prank(oracleNode);
        oracle.executeRequest(requestId, answerData);

        assertEq(client.getPrice(), testPrice);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Oracle.sol";
import {RequestType} from "../../src/utils/Constants.sol";

contract OracleTest is Test {
    Oracle public oracle;
    address oracleNode = vm.addr(100);

    event RequestCreated(uint256 indexed requestId, bytes data);
    event RequestExecuted(uint256 requestId);

    function setUp() public {
        oracle = new Oracle();
    }

    // region - Create request -

    function _beforeEach_createRequest() private {
        oracle.setOracleNode(oracleNode);
    }

    function test_createRequest() external {
        bytes memory data = abi.encode(RequestType.GET_PRICE);

        _beforeEach_createRequest();

        uint256 requestId = oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: OracleTest.callbackMock.selector
            })
        );

        IOracle.Request memory request = oracle.getRequestById(requestId);

        assertEq(oracleNode, request.oracleNode);
        assertEq(address(this), request.callback.to);
        assertEq(OracleTest.callbackMock.selector, request.callback.functionSelector);
    }

    function test_createRequest_emitRequestCreated() external {
        bytes memory data = abi.encode(RequestType.GET_PRICE);
        uint256 requestId = 1;

        _beforeEach_createRequest();

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(requestId, data);

        oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: OracleTest.callbackMock.selector
            })
        );
    }

    function test_createRequest_revertIfOracleNodeNotTrusted() external {
        bytes memory data = abi.encode(RequestType.GET_PRICE);

        vm.expectRevert(abi.encodeWithSignature("OracleNodeNotTrusted(address)", oracleNode));

        oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: OracleTest.callbackMock.selector
            })
        );
    }

    // endregion

    // region - Execute request -

    function _beforeEach_executeRequest() private returns (uint256 requestId) {
        oracle.setOracleNode(oracleNode);

        bytes memory data = abi.encode(RequestType.GET_PRICE);

        _beforeEach_createRequest();

        requestId = oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: OracleTest.callbackMock.selector
            })
        );
    }

    function test_executeRequest() external {
        uint256 testPrice = 100;
        bytes memory data = abi.encode(testPrice);

        uint256 requestId = _beforeEach_executeRequest();

        vm.expectCall(address(this), 0, abi.encodeWithSelector(OracleTest.callbackMock.selector, data));

        vm.prank(oracleNode);
        oracle.executeRequest(requestId, data);
    }

    function test_executeRequest_emitRequestExecuted() external {
        uint256 testPrice = 100;
        bytes memory data = abi.encode(testPrice);

        uint256 requestId = _beforeEach_executeRequest();

        vm.expectEmit(true, true, true, true);
        emit RequestExecuted(requestId);

        vm.prank(oracleNode);
        oracle.executeRequest(requestId, data);
    }

    function test_executeRequest_revertIfSenderNotOracleNode() external {
        uint256 testPrice = 100;
        bytes memory data = abi.encode(testPrice);

        uint256 requestId = _beforeEach_executeRequest();

        vm.expectRevert(abi.encodeWithSignature("SenderShouldBeEqualOracleNodeRequest()"));

        oracle.executeRequest(requestId, data);
    }

    function test_executeRequest_revertIfRequestNotFound() external {
        uint256 testPrice = 100;
        uint256 requestId = 1;
        bytes memory data = abi.encode(testPrice);

        vm.expectRevert(abi.encodeWithSignature("RequestNotFound(uint256)", requestId));

        oracle.executeRequest(requestId, data);
    }

    // endregion

    function callbackMock(bytes memory data) external {}
}

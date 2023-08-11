// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IOracle {
    struct Callback {
        address to;
        bytes4 functionSelector;
    }

    struct Request {
        address oracleNode;
        Callback callback;
    }

    event OracleNodeSet(address account);
    event OracleNodeRemoved(address account);
    event RequestCreated(uint256 indexed requestId, bytes data);
    event RequestExecuted(uint256 requestId);

    error OracleNodeNotTrusted(address oracleNode);
    error RequestNotFound(uint256 requestId);
    error SenderShouldBeEqualOracleNodeRequest();
    error ExecuteFailed(uint256 requestId);

    function createRequest(address oracleNode, bytes memory data, Callback memory callback)
        external
        returns (uint256 requestId);
}
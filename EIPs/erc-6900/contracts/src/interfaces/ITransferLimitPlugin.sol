// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITransferLimitPlugin {
    function updateLimit(address token, uint256 limit) external;
    function getCurrentLimit(address account, address token) external view returns (uint256);
    function getTokensForAccount(address account) external view returns (address[] memory tokens);
}

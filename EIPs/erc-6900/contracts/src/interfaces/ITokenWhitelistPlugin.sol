// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITokenWhitelistPlugin {
    function updateTokens(address[] memory tokensToAdd, address[] memory tokensToRemove) external;
    function isAllowedToken(address associated, address tokenToCheck) external view returns (bool);
    function getTokens(address account) external view returns (address[] memory tokens);
}
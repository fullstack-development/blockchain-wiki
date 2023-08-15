// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ISimpleOrderBook {
    function calcAmountToSell(address sellToken, address buyToken, uint buyAmount) external view returns (uint256 sellAmount);
    function calcAmountToBuy(address sellToken, address buyToken, uint sellAmount) external view returns (uint256 buyAmount);
    function buy(address sellToken, address buyToken, uint buyAmount) external returns (uint256 soldAmount);
    function sell(address sellToken, address buyToken, uint sellAmount) external returns (uint256 boughtAmount);
}
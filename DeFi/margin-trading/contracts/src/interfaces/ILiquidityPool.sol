// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ILiquidityPool {
    function totalDebt() external returns(uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function getDebt(address borrower) external view returns (uint256);
}
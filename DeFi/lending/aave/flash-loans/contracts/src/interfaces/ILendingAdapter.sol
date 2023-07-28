// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

interface ILendingAdapter {
    function tokenA() external returns (IERC20);
    function tokenB() external returns (IERC20);
    function addCollateral(uint256 amount) external;
    function withdrawCollateral(uint256 amount) external;
    function borrow(uint256 amount, uint256 interestRateMode) external;
    function repayBorrow(uint256 amount, uint256 rateMode) external;
    function liquidate(address borrower, uint256 repayAmount) external;
}
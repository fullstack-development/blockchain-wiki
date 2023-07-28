// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/interfaces/ILendingAdapter.sol";
import "../../src/interfaces/ILendingPool.sol";

contract AaveLendingAdapter is ILendingAdapter {
    using SafeERC20 for IERC20;

    ILendingPool lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    IERC20 public tokenA; // collateral token
    IERC20 public tokenB; // debt token

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addCollateral(uint256 amount) external {
        tokenA.safeTransferFrom(msg.sender, address(this), amount);

        tokenA.safeApprove(address(lendingPool), amount);
        lendingPool.deposit(address(tokenA), amount, address(this), 0);
    }

    function withdrawCollateral(uint256 amount) external {
        lendingPool.withdraw(address(tokenA), amount, address(this));
        tokenA.safeTransfer(msg.sender, amount);
    }

    function borrow(uint256 amount, uint256 interestRateMode) external {
        lendingPool.borrow(address(tokenB), amount, interestRateMode, 0, address(this));
        tokenB.safeTransfer(msg.sender, amount);
    }

    function repayBorrow(uint256 amount, uint256 rateMode) external {
        tokenB.safeTransferFrom(msg.sender, address(this), amount);

        tokenB.safeApprove(address(lendingPool), amount);
        lendingPool.repay(address(tokenB), amount, rateMode, address(this));
    }

    function liquidate(address borrower, uint256 repayAmount) external {
        tokenB.safeTransferFrom(msg.sender, address(this), repayAmount);

        tokenB.safeApprove(address(lendingPool), repayAmount);
        lendingPool.liquidationCall(address(tokenA), address(tokenB), borrower, repayAmount, false);

        tokenA.safeTransfer(msg.sender, tokenA.balanceOf(address(this)));
    }
}
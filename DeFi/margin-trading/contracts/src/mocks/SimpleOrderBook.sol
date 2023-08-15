//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract SimpleOrderBook {
    using SafeERC20 for IERC20;

    function calcAmountToSell(address sellToken, address buyToken, uint buyAmount) public view returns (uint256 sellAmount) {
        uint256 reserveA = IERC20(sellToken).balanceOf(address(this));
        uint256 reserveB = IERC20(buyToken).balanceOf(address(this));

        return (reserveA * buyAmount) / (reserveB - buyAmount);
    }

    function calcAmountToBuy(address sellToken, address buyToken, uint sellAmount) public view returns (uint256 buyAmount) {
        uint256 reserveA = IERC20(sellToken).balanceOf(address(this));
        uint256 reserveB = IERC20(buyToken).balanceOf(address(this));

        return (reserveB * sellAmount) / (reserveA + sellAmount);
    }

    function buy(address sellToken, address buyToken, uint buyAmount) external returns (uint256 soldAmount) {
        soldAmount = calcAmountToSell(sellToken, buyToken, buyAmount);

        IERC20(sellToken).safeTransferFrom(msg.sender, address(this), soldAmount);
        IERC20(buyToken).safeTransfer(msg.sender, buyAmount);
    }

    function sell(address sellToken, address buyToken, uint sellAmount) external returns (uint256 boughtAmount) {
        boughtAmount = calcAmountToBuy(sellToken, buyToken, sellAmount);

        IERC20(sellToken).safeTransferFrom(msg.sender, address(this), sellAmount);
        IERC20(buyToken).safeTransfer(msg.sender, boughtAmount);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/mocks/SimpleOrderBook.sol";
import "../../src/mocks/MockToken.sol";

contract SimpleOrderBookTest is Test {
    using SafeERC20 for MockToken;

    MockToken tokenA;
    MockToken tokenB;

    SimpleOrderBook orderBook;

    function setUp() external {
        tokenA = new MockToken("Token A", "TA", 18);
        tokenB = new MockToken("Token B", "TB", 18);

        orderBook = new SimpleOrderBook();

        tokenA.mint(address(orderBook), 1_000_000_000e18);
        tokenB.mint(address(orderBook), 1_000_000_000e18);
    }

    function test_calcAmountToSell() external {
        uint256 buyAmount = 500e18;
        uint256 sellAmount = orderBook.calcAmountToSell(address(tokenA), address(tokenB), buyAmount);

        assertEq(sellAmount, tokenA.balanceOf(address(orderBook)) * buyAmount / (tokenA.balanceOf(address(orderBook)) - buyAmount));
    }

    function test_calcAmountToBuy() external {
        uint256 sellAmount = 500e18;
        uint256 buyAmount = orderBook.calcAmountToBuy(address(tokenA), address(tokenB), sellAmount);

        assertEq(buyAmount, tokenB.balanceOf(address(orderBook)) * sellAmount / (tokenA.balanceOf(address(orderBook)) + sellAmount));
    }

    function test_buy() external {
        uint256 buyAmount = 500e18;

        uint256 sellAmount = orderBook.calcAmountToSell(address(tokenA), address(tokenB), buyAmount);

        tokenA.mint(address(this), sellAmount);

        tokenA.safeApprove(address(orderBook), sellAmount);
        orderBook.buy(address(tokenA), address(tokenB), buyAmount);

        assertEq(buyAmount, tokenB.balanceOf(address(this)));
    }

    function test_sell() external {
        uint256 sellAmount = 500e18;

        uint256 buyAmount = orderBook.calcAmountToBuy(address(tokenA), address(tokenB), sellAmount);

        tokenA.mint(address(this), sellAmount);

        tokenA.safeApprove(address(orderBook), sellAmount);
        orderBook.sell(address(tokenA), address(tokenB), sellAmount);

        assertEq(buyAmount, tokenB.balanceOf(address(this)));
    }
}
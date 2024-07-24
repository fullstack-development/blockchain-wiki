// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "../src/Liquidator.sol";
import "./mocks/AaveLendingAdapter.sol";

contract LiquidatorTest is Test {
    using SafeERC20 for IERC20;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    Liquidator liquidator;
    AaveLendingAdapter lendingAdapter;

    address borrower = vm.addr(100);

    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ILendingPool lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        vm.rollFork(16_233_000);

        lendingAdapter = new AaveLendingAdapter(address(DAI), address(USDC));
        liquidator = new Liquidator(address(lendingPool), address(lendingAdapter), address(uniswapRouter));

        payable(borrower).transfer(100_000 ether);
    }

    function _beforeEach_liquidate(uint256 collateralAmount, uint256 borrowAmount) private {
        // swap eth for exact tokens for tests
        _getTestTokens(address(DAI), borrower, collateralAmount);

        assertEq(DAI.balanceOf(borrower), collateralAmount);

        vm.startPrank(borrower);

        // add collateral
        DAI.approve(address(lendingAdapter), collateralAmount);
        lendingAdapter.addCollateral(collateralAmount);

        // borrow USDC
        lendingAdapter.borrow(borrowAmount, 1);

        assertEq(USDC.balanceOf(borrower), borrowAmount);

        vm.stopPrank();
    }

    function test_liquidate() public {
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 76e6;
        uint256 repayAmount = borrowAmount / 2;

        // simulate loan
        _beforeEach_liquidate(collateralAmount, borrowAmount);

        // move time and simulate the possibility of liquidation
        vm.warp(block.timestamp + 365 days * 5);

        // check the possibility of liquidation
        (,,,,, uint256 healthFactor) = lendingPool.getUserAccountData(address(lendingAdapter));
        assertLt(healthFactor, 1 ether);

        // call liquidation
        liquidator.liquidate(address(lendingAdapter), repayAmount);

        // After liquidation, the balance of the DAI must be greater than 0
        assertGt(DAI.balanceOf(address(this)), 0);
    }

    function _getTestTokens(address token, address recipient, uint256 amount) private {
        address[] memory path2 = new address[](2);
        path2[0] = uniswapRouter.WETH();
        path2[1] = token;

        uniswapRouter.swapETHForExactTokens{value: 1000 ether}(
            amount,
            path2,
            recipient,
            block.timestamp + 15
        );

        assertEq(IERC20(token).balanceOf(recipient), amount);
    }

    // need to swapEthForExactTokens
    receive() payable external {}
}
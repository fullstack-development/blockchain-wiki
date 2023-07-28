// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../src/AaveLendingAdapter.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract AaveLendingAdapterTest is Test {
    using SafeERC20 for IERC20;

    uint256 mainnetFork;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    AaveLendingAdapter adapter;

    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ILendingPool lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        vm.rollFork(16_233_000);

        adapter = new AaveLendingAdapter(address(DAI), address(USDC));

        _getTestTokens(address(DAI), address(this), 10000e18);
    }

    // region - Add collateral -

    function test_addCollateral() public {
        uint256 amount = 10000;

        DAI.safeApprove(address(adapter), amount);

        uint256 balanceBefore = DAI.balanceOf(address(this));

        adapter.addCollateral(amount);

        assertEq(DAI.balanceOf(address(this)), balanceBefore - amount);

        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
        ) = lendingPool.getUserAccountData(address(adapter));

        assertGt(totalCollateralETH, 0);
        assertEq(totalDebtETH, 0);
        assertGt(availableBorrowsETH, 0);
        assertGt(currentLiquidationThreshold, 0);
        assertGt(ltv, 0);
    }

    // endregion

    // region - Withdraw collateral -

    function _beforeEach_withdrawalCollateral(uint256 amount) private {
        DAI.approve(address(adapter), amount);

        adapter.addCollateral(amount);
    }

    function test_withdrawCollateral() public {
        uint256 amount = 10000;

        _beforeEach_withdrawalCollateral(amount);

        uint256 balanceDAIBeforeWithdrawal = DAI.balanceOf(address(this));

        adapter.withdrawCollateral(amount);

        assertEq(DAI.balanceOf(address(this)), balanceDAIBeforeWithdrawal + amount);

        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
        ) = lendingPool.getUserAccountData(address(adapter));

        assertEq(totalCollateralETH, 0);
        assertEq(totalDebtETH, 0);
        assertEq(availableBorrowsETH, 0);
        assertEq(currentLiquidationThreshold, 0);
        assertEq(ltv, 0);
    }

    // endregion

    // region - Borrow -

    function _beforeEach_borrow(uint256 amount) private {
        DAI.safeApprove(address(adapter), amount);

        adapter.addCollateral(amount);
    }

    function test_borrow() public {
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 10e6;

        _beforeEach_borrow(collateralAmount);

        adapter.borrow(borrowAmount, 1);

        assertEq(USDC.balanceOf(address(this)), borrowAmount);

        (,uint256 totalDebtETH,,,,) = lendingPool.getUserAccountData(address(adapter));

        assertGt(totalDebtETH, 0);
    }

    // endRegion

    // region - Repay borrow -

    function _beforeEach_repayBorrow(uint256 collateralAmount, uint256 borrowAmount) public {
        DAI.safeApprove(address(adapter), collateralAmount);

        adapter.addCollateral(collateralAmount);

        adapter.borrow(borrowAmount, 1);
    }

    function test_repayBorrow() public {
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 10e6;

        _beforeEach_repayBorrow(collateralAmount, borrowAmount);

        USDC.safeApprove(address(adapter), borrowAmount);
        adapter.repayBorrow(borrowAmount, 1);

        (, uint256 totalDebtETH,,,,) = lendingPool.getUserAccountData(address(adapter));
        assertEq(totalDebtETH, 0);
    }

    // endregion

    // region - Liquidate -

    function _beforeEach_liquidate(uint256 collateralAmount, uint256 borrowAmount, uint256 repayAmount) private returns (address) {
        address liquidator = vm.addr(1);

        DAI.safeApprove(address(adapter), collateralAmount);
        adapter.addCollateral(collateralAmount);

        adapter.borrow(borrowAmount, 1);

        _getTestTokens(address(USDC), liquidator, repayAmount);

        return liquidator;
    }

    function test_liquidate() external {
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 76e6;
        uint256 repayAmount = borrowAmount / 2;

        address liquidator = _beforeEach_liquidate(collateralAmount, borrowAmount, repayAmount);

        vm.warp(block.timestamp + 365 days * 5);

        (,,,,, uint256 healthFactor) = lendingPool.getUserAccountData(address(adapter));
        assertLt(healthFactor, 1 ether);

        vm.startPrank(liquidator);
        USDC.safeApprove(address(adapter), repayAmount);
        adapter.liquidate(address(adapter), repayAmount);

        assertGt(DAI.balanceOf(liquidator), 0);
    }

    // endregion

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
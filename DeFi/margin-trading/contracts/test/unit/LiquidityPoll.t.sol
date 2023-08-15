// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/LiquidityPool.sol";
import "../../src/mocks/MockToken.sol";

contract LiquidityPoolTest is Test {
    using SafeERC20 for MockToken;

    LiquidityPool liquidityPool;
    MockToken tokenA;

    address liquidityProvider = vm.addr(100);
    uint256 liquidityProviderBalance = 1_000_000e18;

    function setUp() external {
        tokenA = new MockToken("TokenA", "TA", 18);
        liquidityPool = new LiquidityPool(address(tokenA));

        tokenA.mint(liquidityProvider, liquidityProviderBalance);
    }

    // region - Deposit -

    function test_deposit() public {
        uint256 amount = 100e18;

        vm.startPrank(liquidityProvider);

        tokenA.safeApprove(address(liquidityPool), amount);
        liquidityPool.deposit(amount);

        assertEq(tokenA.balanceOf(address(liquidityPool)), amount);
        assertEq(tokenA.balanceOf(address(liquidityProvider)), liquidityProviderBalance - amount);
    }

    // endregion

    // region - Withdraw -

    function _beforeEach_withdraw(uint256 amount) private {
        vm.startPrank(liquidityProvider);

        tokenA.safeApprove(address(liquidityPool), amount);
        liquidityPool.deposit(amount);

        vm.stopPrank();
    }

    function test_withdraw() public {
        uint256 amount = 100e18;

        _beforeEach_withdraw(amount);

        vm.startPrank(liquidityProvider);
        liquidityPool.withdraw(amount);

        assertEq(tokenA.balanceOf(address(liquidityPool)), 0);
        assertEq(tokenA.balanceOf(address(liquidityProvider)), liquidityProviderBalance);
    }

    function test_withdraw_moreThanDeposit() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 1000e18;

        _beforeEach_withdraw(depositAmount);

        vm.startPrank(liquidityProvider);
        liquidityPool.withdraw(withdrawAmount);

        assertEq(tokenA.balanceOf(address(liquidityPool)), 0);
        assertEq(tokenA.balanceOf(address(liquidityProvider)), liquidityProviderBalance);
    }

    function test_withdraw_lessThanDeposit() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        _beforeEach_withdraw(depositAmount);

        vm.startPrank(liquidityProvider);
        liquidityPool.withdraw(withdrawAmount);

        assertEq(tokenA.balanceOf(address(liquidityPool)), depositAmount - withdrawAmount);
        assertEq(tokenA.balanceOf(address(liquidityProvider)), liquidityProviderBalance - (depositAmount - withdrawAmount));
    }

    function test_withdraw_revertIfNotLiquidityProvider() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        _beforeEach_withdraw(depositAmount);

        vm.expectRevert(abi.encodeWithSignature("LiquidityPool_CallerIsNotLiquidityProvider(address)", address(this)));

        liquidityPool.withdraw(withdrawAmount);
    }

    // endregion

    // region - Borrow -

    function _beforeEach_borrow(uint256 amount) private {
        vm.startPrank(liquidityProvider);

        tokenA.safeApprove(address(liquidityPool), amount);
        liquidityPool.deposit(amount);

        vm.stopPrank();
    }

    function test_borrow() public {
        uint256 borrowAmount = 100e18;
        uint256 depositAmount = 1_000e18;

        _beforeEach_borrow(depositAmount);

        liquidityPool.borrow(borrowAmount);

        assertEq(tokenA.balanceOf(address(this)), borrowAmount);
        assertEq(tokenA.balanceOf(address(liquidityPool)), depositAmount - borrowAmount);
        assertEq(liquidityPool.totalDebt(), borrowAmount);
    }

    function test_borrow_double() public {
        uint256 borrowAmount = 100e18;
        uint256 depositAmount = 1_000e18;

        _beforeEach_borrow(depositAmount);

        liquidityPool.borrow(borrowAmount);
        liquidityPool.borrow(borrowAmount);

        assertEq(tokenA.balanceOf(address(this)), borrowAmount * 2);
        assertEq(tokenA.balanceOf(address(liquidityPool)), depositAmount - borrowAmount * 2);
        assertEq(liquidityPool.totalDebt(), borrowAmount * 2);
    }

    function test_borrow_revertIfBorrowMoreThanDeposit() public {
        uint256 borrowAmount = 10_000e18;
        uint256 depositAmount = 1_000e18;

        _beforeEach_borrow(depositAmount);

        vm.expectRevert(abi.encodeWithSignature("LiquidityPool_InsufficientLiquidity()"));

        liquidityPool.borrow(borrowAmount);
    }

    // endregion

    // region - Repay -

    function _beforeEach_repay(uint256 depositAmount, uint256 borrowAmount) private {
        vm.startPrank(liquidityProvider);

        tokenA.safeApprove(address(liquidityPool), depositAmount);
        liquidityPool.deposit(depositAmount);

        vm.stopPrank();

        liquidityPool.borrow(borrowAmount);
    }

    function test_repay() public {
        uint256 depositAmount = 1_000e18;
        uint256 borrowAmount = 50e18;

        _beforeEach_repay(depositAmount, borrowAmount);

        tokenA.safeApprove(address(liquidityPool), borrowAmount);
        liquidityPool.repay(borrowAmount);

        assertEq(tokenA.balanceOf(address(this)), 0);
        assertEq(tokenA.balanceOf(address(liquidityPool)), depositAmount);
        assertEq(liquidityPool.totalDebt(), 0);
    }

    function test_repay_partially() public {
        uint256 depositAmount = 1_000e18;
        uint256 borrowAmount = 50e18;
        uint256 repayAmount = 25e18;

        _beforeEach_repay(depositAmount, borrowAmount);

        tokenA.safeApprove(address(liquidityPool), repayAmount);
        liquidityPool.repay(repayAmount);

        assertEq(tokenA.balanceOf(address(this)), borrowAmount - repayAmount);
        assertEq(tokenA.balanceOf(address(liquidityPool)), depositAmount - (borrowAmount - repayAmount));
        assertEq(liquidityPool.totalDebt(), borrowAmount - repayAmount);
    }

    function test_repay_revertIfNotBorrower() public {
        uint256 depositAmount = 1_000e18;
        uint256 borrowAmount = 50e18;
        address notBorrower = vm.addr(2);

        _beforeEach_repay(depositAmount, borrowAmount);

        vm.startPrank(notBorrower);
        tokenA.safeApprove(address(liquidityPool), borrowAmount);

        vm.expectRevert(abi.encodeWithSignature("LiquidityPool_CallerIsNotBorrower(address)", notBorrower));
        liquidityPool.repay(borrowAmount);
    }

    // endregion
}
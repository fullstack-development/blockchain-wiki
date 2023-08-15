// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/MarginTrading.sol";
import "../../src/LiquidityPool.sol";
import "../../src/mocks/MockToken.sol";
import "../../src/mocks/SimpleOrderBook.sol";

contract MarginTradingTest is Test {
    using SafeERC20 for MockToken;

    MockToken tokenA;
    MockToken tokenB;

    LiquidityPool liquidityPool;
    SimpleOrderBook orderBook;
    MarginTrading marginTrading;

    function setUp() public {
        tokenA = new MockToken("TokenA", "TA", 18);
        tokenB = new MockToken("TokenB", "TB", 18);

        liquidityPool = new LiquidityPool(address(tokenA));
        _fillLiquidityPull();

        orderBook = new SimpleOrderBook();
        _fillOrderBook();

        marginTrading = new MarginTrading(
            address(liquidityPool),
            address(orderBook),
            address(tokenA),
            address(tokenB)
        );
    }

    // region - Open long -

    function test_openLong() public {
        uint256 amountBToBuy = 100e18;
        uint256 leverage = 1;

        marginTrading.openLong(amountBToBuy, leverage);

        assertGt(tokenB.balanceOf(address(marginTrading)), 0);
        assertGt(marginTrading.longDebtA(), 0);

        assertEq(tokenB.balanceOf(address(marginTrading)), marginTrading.longBalanceB());
    }

    // endregion

    // region - Close long -

    function _beforeEach_closeLong() private {
        uint256 amountBToBuy = 100e18;
        uint256 leverage = 1;

        marginTrading.openLong(amountBToBuy, leverage);
    }

    function test_closeLong() public {
        _beforeEach_closeLong();

        marginTrading.closeLong();

        assertEq(tokenB.balanceOf(address(marginTrading)), 0);
        assertEq(marginTrading.longDebtA(), 0);
        assertEq(tokenA.balanceOf(address(this)), 0);
    }

    // endregion

    // region - Open short -

    function test_openShort() public {
        uint256 amountAToSell = 100e18;
        uint256 leverage = 1;

        marginTrading.openShort(amountAToSell, leverage);

        assertGt(tokenB.balanceOf(address(marginTrading)), 0);
        assertGt(marginTrading.shortDebtA(), 0);

        assertEq(tokenB.balanceOf(address(marginTrading)), marginTrading.shortBalanceB());
    }

    // endregion

    // region - Close short -

    function _beforeEach_closeShort() private {
        uint256 amountAToSell = 100e18;
        uint256 leverage = 1;

        marginTrading.openShort(amountAToSell, leverage);
    }

    function test_closeShort() public {
        _beforeEach_closeShort();

        marginTrading.closeShort();

        assertEq(tokenB.balanceOf(address(marginTrading)), 0);
        assertEq(marginTrading.shortDebtA(), 0);
        assertEq(tokenB.balanceOf(address(this)), 0);
    }

    // endregion

    // region - Private functions -

    function _fillLiquidityPull() private {
        address liquidityProvider = vm.addr(100);
        uint256 amount = 1_000_000_000e18;

        tokenA.mint(liquidityProvider, amount);

        vm.startPrank(liquidityProvider);

        tokenA.safeApprove(address(liquidityPool), amount);
        liquidityPool.deposit(amount);

        vm.stopPrank();
    }

    function _fillOrderBook() private {
        tokenA.mint(address(orderBook), 1_000_000_000e18);
        tokenB.mint(address(orderBook), 1_000_000_000e18);
    }

    // endregion
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import 'openzeppelin-contracts/token/ERC20/ERC20.sol';
import 'uniswap-v3/libraries/FixedPoint96.sol';
import 'uniswap-v3/libraries/FullMath.sol';
import 'uniswap-v3/interfaces/IUniswapV3Pool.sol';
import 'uniswap-v3/interfaces/IUniswapV3Factory.sol';

import "forge-std/Test.sol";

contract GetPriceUniswapV3 {
    IUniswapV3Factory private _factory;

    constructor(address factory) {
        _factory = IUniswapV3Factory(factory);
    }

    function calculatePriceFromLiquidity(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(_factory.getPool(tokenA, tokenB, fee));
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        console.log("sqrtPriceX96", sqrtPriceX96);

        uint256 amount0 = FullMath.mulDiv(pool.liquidity(), FixedPoint96.Q96, sqrtPriceX96);

        uint256 amount1 = FullMath.mulDiv(pool.liquidity(), sqrtPriceX96, FixedPoint96.Q96);

        console.log("Amount0", amount0);
        console.log("Amount1", amount1);
        console.log("TokenA decimals", ERC20(tokenA).decimals());

        return (amount1 * 10**ERC20(tokenA).decimals()) / amount0;
    }

    function getPrice(address tokenIn, address tokenOut, uint24 fee)
        external
        view
        returns (uint256 price)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(_factory.getPool(tokenIn, tokenOut, fee));
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        return uint(sqrtPriceX96) * (uint(sqrtPriceX96)) * (1e18) >> (96 * 2);
    }

    // вызов статик колом функций quoter
}
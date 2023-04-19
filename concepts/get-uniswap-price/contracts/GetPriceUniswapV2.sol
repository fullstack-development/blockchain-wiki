// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IUniswapV2Pair} from "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICustomERC20 is IERC20 {
    /**
    * @dev Returns the decimals.
    */
    function decimals() external view returns (uint256);
}

contract GetPriceUniswapV2 {
    /**
     * @notice Получить сумму токена с роутера
     * @dev Network: Goerli
     * Router address: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
     * USDT address: 0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49
     * UNI address: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
     */
    function getTokenPrice(address router, address tokenA, address tokenB, uint256 amountIn)
        external
        view
        returns (uint256 price)
    {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256[] memory amounts = IUniswapV2Router02(router).getAmountsOut(amountIn, path);

        price = amounts[1];
    }

    /**
     * @notice Рассчитать стоимость токена на основе резервов токена, которые хранятся на контракте пары
     * @dev Network: Goerli
     *
     */
    function getManualTokenPrice(address pairAddress, uint amount) public view returns(uint) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        ICustomERC20 token1 = ICustomERC20(pair.token1());

        (uint Res0, uint Res1,) = pair.getReserves();

        // decimals
        uint res0 = Res0 * (10**token1.decimals());

        return ((amount * res0) / Res1); // return amount of token0 needed to buy token1
    }
}
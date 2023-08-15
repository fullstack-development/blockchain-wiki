// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @notice Контракт адаптер. Предназначен для демонстрации взаимодействия с контрактами Uniswap V2.
 * Реализовано добавление и удаление ликвидности, обмен ERC20 токена на ERC20 токен
 * @dev Контракт создан в учебных целях. Не использовать на реальных проектах
 */
contract Adapter {
    using SafeERC20 for IERC20;

    address public immutable tokenA;
    address public immutable tokenB;

    IUniswapV2Router02 public router;

    event LiquidityAdded(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event TokenSwap(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB
    );

    constructor(address _twoInchToken, address _usdt, address _router) {
        tokenA = _twoInchToken;
        tokenB = _usdt;
        router = IUniswapV2Router02(_router);
    }

    /**
     * @notice Добавление ликвидности
     * @param amountA Количество токена A
     * @param amountB Количество токена B
     * @param amountAMin Минимально количество токена A
     * @param amountBMin Минимально количество токена B
     */
    function addLiquidityToUniswap(
        uint256 amountA,
        uint256 amountB,
        uint256 amountAMin,
        uint256 amountBMin
    ) external {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        IERC20(tokenA).safeApprove(address(router), amountA);
        IERC20(tokenB).safeApprove(address(router), amountB);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            amountAMin,
            amountBMin,
            address(this),
            block.timestamp + 600 // 10 min
        );

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /**
     * @notice Удаление ликвидности
     * @param liquidity Количество lp токена
     * @param amountAMin Минимально количество токена A
     * @param amountBMin Минимально количество токена B
     */
    function removeLiquidityFromUniswap(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external {
        (address _lpToken, uint256 _lpBalance) = getLpInfo();
        require(_lpBalance >= liquidity, "Adapter: insufficient liquidity");

        IERC20(_lpToken).safeApprove(address(router), liquidity);

        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            msg.sender,
            block.timestamp + 600 // 10 min
        );

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /**
     * @notice Получение баланса lp токена
     * @return lpToken Адрес lp токена
     * @return lpBalance Баланс lp токена
     */
    function getLpInfo() public view returns (address lpToken, uint256 lpBalance) {
        address _factory = router.factory();
        lpToken = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);
        lpBalance = IERC20(lpToken).balanceOf(address(this));
    }

    /**
     * @notice Получение стоимости токена из пула ликвидности для обмена
     * @param amountIn Сумма токена на вход
     * @return Сумма токенов на выходе
     */
    function getTokenPriceFromPair(
        uint256 amountIn
    ) public view returns (uint[] memory amounts) {
        address[] memory path;
        path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        amounts = router.getAmountsOut(amountIn, path);
    }

    /**
     * @notice Обмен токена A на токен B
     * @param amountIn Сумма токена A на вход
     * @param amountOutMin Минимальная сумма токена B на выходе
     */
    function swapTokenAToTokenB(
        uint256 amountIn,
        uint256 amountOutMin
    ) public returns (uint256) {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenA).safeApprove(address(router), amountIn);

        address[] memory path;
        path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256[]memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );

        emit TokenSwap(tokenA, tokenB, amounts[0], amounts[1]);

        return amounts[1];
    }
}
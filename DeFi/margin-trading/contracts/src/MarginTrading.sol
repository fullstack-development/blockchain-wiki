// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import "./interfaces/ILiquidityPool.sol";
import "./interfaces/ISimpleOrderBook.sol";

/**
 * @notice Основной контракт примера.
 * Реализует простой вариант проведения операций с заемными средствами.
 * @dev Заемные средства берутся с контракта LiquidityPool.sol.
 * Операции обмена токенов реализованы контрактом заглушкой SimpleOrderBook.sol,
 * который отвечает за ценообразование и физический трансфер токенов
 * Все функции могут вызваны только владельцем контракта
 */
contract MarginTrading is Ownable {
    using SafeERC20 for IERC20;

    ILiquidityPool liquidityPool;
    ISimpleOrderBook orderBook;

    IERC20 tokenA;
    IERC20 tokenB;

    uint256 public longDebtA;
    uint256 public longBalanceB;

    uint256 public shortDebtA;
    uint256 public shortBalanceB;

    error MarginTrading__InsufficientAmountForClosePosition();

    event LongOpened();
    event LongClosed();
    event ShortOpened();
    event ShortClosed();

    constructor(
        address _liquidityPool,
        address _orderBook,
        address _tokenA,
        address _tokenB
    ) {
        liquidityPool = ILiquidityPool(_liquidityPool); /// Контракт для взятия займа
        orderBook = ISimpleOrderBook(_orderBook); /// Контракт для физического проведение обмена одного токена на другой. Симулирует работу обменника.

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @notice Открытие длинной позиции. Покупка токена B c расчетом, что его стоимость вырастет в дальнейшем
     * @param amountBToBuy Количество токена B для покупки
     * @param leverage Плечо, которое должно увеличить сумму покупки заемными средствами
     * @dev Подразумевается, что когда стоимость токена B вырастет,
     * sender этой функции должен самостоятельно вызвать функцию closeLong() для получения профита
     */
    function openLong(uint256 amountBToBuy, uint256 leverage) external onlyOwner {
        /// Рассчитываем количество токена А необходимого для покупки токена B
        uint256 amountAToSell = orderBook.calcAmountToSell(address(tokenA), address(tokenB), amountBToBuy * leverage);

        /// Берем токен А в заем для покупки большего количества токена B
        liquidityPool.borrow(amountAToSell);

        longDebtA += amountAToSell;
        longBalanceB += amountBToBuy;

        /// Покупаем токен B в замен отдаем токен А
        tokenA.safeApprove(address(orderBook), amountAToSell);
        orderBook.buy(address(tokenA), address(tokenB), amountBToBuy);

        emit LongOpened();
    }

    /**
     * @notice Закрытие длинной позиции.
     * Продажа токена B и закрытие долговых обязательств с дальнейшим снятием профита
     */
    function closeLong() external onlyOwner {
        /// Продаем весь токен B
        tokenB.safeApprove(address(orderBook), longBalanceB);
        uint256 balanceA = orderBook.sell(address(tokenB), address(tokenA), longBalanceB);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        /// Закрываем долг токеном А, который был взят в заем для покупки токена B
        tokenA.safeApprove(address(liquidityPool), longDebtA);
        liquidityPool.repay(longDebtA);

        longDebtA = 0;
        longBalanceB = 0;

        /// Профит в виде токена А от покупки токена B дешевле, чем он был продан, отправляем владельцу контракта
        uint256 freeTokenA = tokenA.balanceOf(address(this));
        tokenA.safeTransfer(owner(), freeTokenA);

        emit LongClosed();
    }

    /**
     * @notice Открытие короткой позиции. Продажа токена A c расчетом, что его стоимость упадет в дальнейшем
     * @param amountAToSell Количество токена A для продажи
     * @param leverage Плечо, которое должно увеличить сумму продажи заемными средствами
     * @dev Подразумевается, что когда стоимость токена A упадет,
     * sender этой функции должен самостоятельно вызвать функцию closeShort() для получения профита
     */
    function openShort(uint256 amountAToSell, uint leverage) external {
        /// Занимаем токен А для продажи
        liquidityPool.borrow(amountAToSell * leverage);

        shortDebtA += amountAToSell * leverage;

        /// Продаем токен A в расчете, что его стоимость упадет, в замен получаем токен B
        tokenA.safeApprove(address(orderBook), amountAToSell * leverage);
        shortBalanceB += orderBook.sell(address(tokenA), address(tokenB), amountAToSell * leverage);

        emit ShortOpened();
    }

    /**
     * @notice Закрытие короткой позиции.
     * Покупка токена B и закрытие долговых обязательств с дальнейшим снятием профита
     */
    function closeShort() external {
        /// Покупаем токена A дешевле, чем продавали, в замен отдаем токен B
        tokenB.safeApprove(address(orderBook), shortBalanceB);
        uint256 balanceA = orderBook.buy(address(tokenB), address(tokenA), shortDebtA);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        /// Возвращаем токен А, который был взят для продажи
        tokenA.safeApprove(address(liquidityPool), shortDebtA);
        liquidityPool.repay(shortDebtA);

        shortDebtA = 0;
        shortBalanceB = 0;

        /// Профит в виде токена B, который остался отправляем владельцу контракта
        uint256 freeTokenB = tokenB.balanceOf(address(this));
        tokenB.safeTransfer(owner(), freeTokenB);

        emit ShortClosed();
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingAdapter.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * @title Контракт ликвидатор займа
 * @notice Ликвидирует позицию указанного пользователя с использование flashLoan() без использования собственных средств.
 * Необходима только оплата за газ
 */
contract Liquidator is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    ILendingPool lendingPool;
    ILendingAdapter lendingAdapter;
    IUniswapV2Router02 router;

    IERC20 tokenA; // collateral token
    IERC20 tokenB; // debt token

    constructor(address _lendingPool, address _lendingAdapter, address _router) {
        lendingPool = ILendingPool(_lendingPool);
        lendingAdapter = ILendingAdapter(_lendingAdapter);
        router = IUniswapV2Router02(_router);

        tokenA = lendingAdapter.tokenA();
        tokenB = lendingAdapter.tokenB();
    }

    /**
     * Ликвидирует позицию заемщика с использованием flashLoan()
     * @param borrower Адрес заемщика
     * @param repayAmount Сумма для ликвидации долга заемщика
     */
    function liquidate(address borrower, uint256 repayAmount) external {
        address[] memory assets = new address[](1);
        assets[0] = address(tokenB);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = repayAmount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory params = abi.encode(borrower, msg.sender);

        /// Берем быстрый займ и ожидаем что протокол вызовет функцию executeOperation() на нашем контракте
        /// в котором мы получим в заем активы и используем для ликвидации позиции заемщика
        lendingPool.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    /**
     * Функция callback вызываемая протоколом Aave в рамках работы flashLoan()
     * @param amounts Массив сумм для каждого актива
     * @param premiums Комиссия с каждого актива, которую необходимо вернуть вместе с заемными активами в конце транзакции
     * @param params Упакованные данные, которые переданы вызывающим flashLoan()
     */
    function executeOperation(
        address[] calldata /** assets - Список активов полученных для займа**/,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /** initiator - Адрес вызывающего транзакцию flashLoan()**/ ,
        bytes calldata params
    ) external returns (bool) {
        (address borrower, address recipient) = abi.decode(params, (address, address));
        uint256 repayAmount = amounts[0];

        /// Даем Approve для LendingPool контракта на взятый в займы tokenB
        uint amountOwing = amounts[0] + premiums[0];
        tokenB.safeApprove(address(lendingPool), amountOwing);

        /// Ликвидируем заем, выплачиваем долг в виде tokenB, получаем за это tokenA
        tokenB.safeApprove(address(lendingAdapter), repayAmount);
        lendingAdapter.liquidate(borrower, repayAmount);

        /// Обмениваем tokenA на tokenB. Нам необходима сумма, которую мы вернем в конце транзакции в рамках flashLoan()
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        tokenA.safeApprove(address(router), tokenA.balanceOf(address(this)));
        router.swapTokensForExactTokens(
            amountOwing,
            tokenA.balanceOf(address(this)),
            path,
            address(this),
            block.timestamp
        );

        /// Отправляем остаток tokenA на собственный адрес. Для нас это profit
        tokenA.safeTransfer(recipient, tokenA.balanceOf(address(this)));

        return true;
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Контракт хранилище для предоставления ликвидности.
 * Подразумевается, что управление ликвидностью происходит поставщиками путем вызова функций: deposit() и withdraw()
 */
contract LiquidityPool {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalDebt;

    mapping(address => uint256) liquidityProviders;
    mapping(address => uint256) borrowers;

    error LiquidityPool_CallerIsNotLiquidityProvider(address caller);
    error LiquidityPool_CallerIsNotBorrower(address caller);
    error LiquidityPool_InsufficientLiquidity();

    event LiquidityAdded(address liquidityProvider, uint256 amount);
    event LiquidityWithdrawn(address liquidityProvider, uint256 amount);
    event Borrowed(address borrower, uint256 amount);
    event Repaid(address borrower, uint256 amount);

    modifier onlyLiquidityProvider(address sender) {
        if (liquidityProviders[sender] == 0) {
            revert LiquidityPool_CallerIsNotLiquidityProvider(sender);
        }

        _;
    }

    modifier onlyBorrower(address sender) {
        if (borrowers[sender] == 0) {
            revert LiquidityPool_CallerIsNotBorrower(sender);
        }

        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
    }

    /**
     * @notice Позволяет предоставить средства для использования в займах
     * @param amount Сумма актива, который будет добавлен на контракт
     * @dev Пользователь, который предоставит токен будет называться поставщиком ликвидности
     */
    function deposit(uint256 amount) external {
        liquidityProviders[msg.sender] = amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(msg.sender, amount);
    }

    /**
     * @notice Позволяет поставщику ликвидности забрать свои средства
     * @param amount Сумма снятия
     * @dev Доступно для вызова пользователю, который предоставил свои средства контракту.
     * Вывод может быть частичный, но не больше предоставленной суммы
     */
    function withdraw(uint256 amount) external onlyLiquidityProvider(msg.sender) {
        if (amount > liquidityProviders[msg.sender]) {
            amount = liquidityProviders[msg.sender];
        }

        token.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Позволяет брать средства предоставленные поставщиками в займы
     * @param amount Сумма займа
     * @dev Сумма долга записывается в mapping borrowers
     */
    function borrow(uint256 amount) external {
        if (amount > token.balanceOf(address(this))) {
            revert LiquidityPool_InsufficientLiquidity();
        }

        totalDebt += amount;
        borrowers[msg.sender] = amount;

        token.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /**
     * @notice Позволяет заемщику погасить долг
     * @param amount Сумма погашения долга
     */
    function repay(uint256 amount) external onlyBorrower(msg.sender) {
        totalDebt -= amount;
        borrowers[msg.sender] -= amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

    /**
     * @notice Возвращает сумму долга для конкретного заемщика
     * @param borrower Адрес аккаунта заемщика
     */
    function getDebt(address borrower) external view returns (uint256) {
        return borrowers[borrower];
    }
}
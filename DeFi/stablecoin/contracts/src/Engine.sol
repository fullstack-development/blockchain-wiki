// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {StableCoin} from "./StableCoin.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title Stable coin engine
 * @notice Этот контракт необходим для управления mint() и burn() стейблкоина
 * Этот механизм необходим для осуществления привязки 1 DSC = 1$
 *
 * Важно! Наша система должна быть всегда сверх обеспечена
 * Threshold 150%
 */
contract Engine is ReentrancyGuard {
    using OracleLib for AggregatorV3Interface;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // Это значение будет требовать 200% сверх обеспечения.
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10; // 10%
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeeds) private _priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private _collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private _dscMinted;
    address[] private _collateralTokens;

    StableCoin private _dsc;

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 collateralAmount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed collateralToken, uint256 collateralAmount);

    error ZeroAmount();
    error TokenAddressesAndPriceFeedAddressesShouldBeSameLength();
    error NotAllowedToken();
    error TransferFailed();
    error BreaksHealthFactor(uint256 healthFactor);
    error MintFailed();
    error HealthFactorIsPositive();
    error HealthFactorNotImproved();

    modifier notZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        _;
    }

    modifier isAllowedToken(address token) {
        if (_priceFeeds[token] == address(0)) {
            revert NotAllowedToken();
        }

        _;
    }

    constructor(address[] memory tokens, address[] memory priceFeeds, address dsc) {
        if (tokens.length != priceFeeds.length) {
            revert TokenAddressesAndPriceFeedAddressesShouldBeSameLength();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            _priceFeeds[tokens[i]] = priceFeeds[i];
            _collateralTokens.push(tokens[i]);
        }

        _dsc = StableCoin(dsc);
    }

    // region - External and public functions -

    /**
     * @notice Позволяет отправить залог и получить стейблкоин
     * @param collateralToken Адрес токена для залога обеспечения
     * @param collateralAmount Сумма вкладываемого залога
     * @param amountToMint Сумма для минтинга стейблкоина
     */
    function depositCollateralAndMintDsc(
        address collateralToken,
        uint256 collateralAmount,
        uint256 amountToMint
    ) external {
        depositCollateral(collateralToken, collateralAmount);
        mintDsc(amountToMint);
    }

    /**
     * @notice Позволяет внести залог для обеспечения стейблкоина
     * @param collateralToken Адрес токена для залога обеспечения
     * @param collateralAmount Сумма вкладываемого залога
     */
    function depositCollateral(address collateralToken, uint256 collateralAmount)
        public
        notZeroAmount(collateralAmount)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        _collateralDeposited[msg.sender][collateralToken] += collateralAmount;

        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        if (!success) {
            revert TransferFailed();
        }

        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);
    }

    /**
     * @notice Позволяет забрать залог в обмен на стейблкоин
     * @param collateralToken Адрес токена для залога обеспечения
     * @param collateralAmount Сумма вкладываемого залога
     * @param amountToBurn Сумма для сжигания стейблкоина
     */
    function redeemCollateralAndBurnDsc(
        address collateralToken,
        uint256 collateralAmount,
        uint256 amountToBurn
    ) external {
        // Сначала сжигаем стейблкоин
        burnDsc(amountToBurn);
        redeemCollateral(collateralToken, collateralAmount);
    }

    /**
     * @notice Позволяет забрать обеспечение
     * @param collateralToken Адрес токена для залога обеспечения
     * @param collateralAmount Сумма вкладываемого залога
     */
    function redeemCollateral(address collateralToken, uint256 collateralAmount)
        public
        notZeroAmount(collateralAmount)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        _redeemCollateral(collateralToken, collateralAmount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Минтит стейблкоин
     * @param amountToMint Сумма для минтинга стейблкоина
     */
    function mintDsc(uint256 amountToMint) public notZeroAmount(amountToMint) nonReentrant {
        _dscMinted[msg.sender] += amountToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = _dsc.mint(msg.sender, amountToMint);
        if (!minted) {
            revert MintFailed();
        }
    }

    /**
     * @notice Сжигает стейблкоин
     * @param amountToBurn Сумма для сжигания стейблкоина
     */
    function burnDsc(uint256 amountToBurn) public notZeroAmount(amountToBurn) nonReentrant {
        _burnDsc(amountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /**
     * @notice Позволяет ликвидировать обеспечение пользователя и получить вознаграждение
     * @param collateralToken Адрес токена для залога обеспечения
     * @param user Пользователь, обеспечения которого недостаточно и его можно ликвидировать
     * @param debtToCover Сумма стейблкоина, которая будет сожжена для корректировки показателя health factor пользователя
     */
    function liquidate(address collateralToken, address user, uint256 debtToCover)
        external
        notZeroAmount(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);

        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert HealthFactorIsPositive();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralToken, debtToCover);
        uint256 bonusCollateral = tokenAmountFromDebtCovered * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(collateralToken, totalCollateralToRedeem, user, msg.sender);

        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);

        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // endregion

    // region - Public and external view functions -

    /**
     * @notice Возвращает сумму общего обеспечения в usd
     * @param user Пользователь для которого считать обеспечение
     * @dev Сумма считается для каждого токена в котором можно блокировать залог на протоколе
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint256 amount = _collateralDeposited[user][token];

            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    /**
     * @notice Возвращает сумму в usd
     * @param token Адрес токена, сумму которого нужно перевести в usd
     * @param amount Количество токена
     * @dev Сумма в usd считается на базе получаемой стоимости из chainlink оракула
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return uint256(price) * ADDITIONAL_FEED_PRECISION * amount / PRECISION;
    }

    /**
     * @notice Возвращает количество токена эквивалентной usd
     * @param token Адрес токена, сумму которого нужно перевести в usd
     * @param usdAmount Количество usd, в формате wei
     * @dev Конвертация токена в usd считается на базе chainlink оракула
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice Возвращает health factor
     * @param user Адрес пользователя для которого вернуть health factor
     * @dev Health factor показывает возможность ликвидации обеспечения пользователя
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Возвращает адреса токенов, разрешенных для использования в обеспечение залога
     */
    function getCollateralTokens() external view returns (address[] memory) {
        return _collateralTokens;
    }

    /**
     * @notice Возвращает адрес priceFeed токена из Chainlink
     */
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return _priceFeeds[token];
    }

    /**
     * @notice Возвращает размер залога, внесенного на протокол пользователем в указанном токене
     * @param user Адрес пользователя для которого запрашивается размер залога
     * @param token Адрес токена, размер залога в котором нужно вернуть
     */
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return _collateralDeposited[user][token];
    }

    /**
     * @notice Возвращает информацию по аккаунту: общее количество стейблкоина и сумма обеспечения в usd
     * @param user Адрес пользователя для которого вернуть информацию по аккаунту
     */
    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    // endregion

    // region - Private and internal view functions -

    function _redeemCollateral(address collateralToken, uint256 collateralAmount, address from, address to) private {
        _collateralDeposited[from][collateralToken] -= collateralAmount;

        bool success = IERC20(collateralToken).transfer(to, collateralAmount);

        if (!success) {
            revert TransferFailed();
        }

        emit CollateralRedeemed(from, to, collateralToken, collateralAmount);
    }

    function _burnDsc(uint256 amountToBurn, address onBehalfOf, address from) private {
        _dscMinted[onBehalfOf] -= amountToBurn;

        bool success = _dsc.transferFrom(from, address(this), amountToBurn);
        if (!success) {
            revert TransferFailed();
        }

        _dsc.burn(amountToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = _dscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Возвращает показатель возможности ликвидировать обеспечение пользователя
     * @dev Если для пользователя показатель ниже 1, тогда его обеспечение может быть ликвидировано
     * LIQUIDATION_THRESHOLD = 50 // По сути это требование, что максимально можно взять стейблкоина равным 50% от collateral
     * или наоборот требование к занимаемому стейблкоину иметь обеспечение 200%
     * LIQUIDATION_PRECISION = 100
     * То есть, предположим, что суммарный collateral = 1000$. Тогда максимально можно занять 500 стейблкоина.
     * Или, чтобы занять 500 стейблкоин, необходимо иметь collateral = 1000$. Что составляет 200%.
     * Проверить это можно подставив значения в формулу функции:
     * threshold = totalCollateral * 0.5 / totalMinted.
     * Если threshold < 1, то будет возможно ликвидация, иначе - нет.
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        if (totalDscMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = collateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;

        return collateralAdjustedForThreshold * PRECISION / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert BreaksHealthFactor(userHealthFactor);
        }
    }

    // endregion
}

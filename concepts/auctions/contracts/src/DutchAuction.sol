// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Голландский аукцион
 * @notice Смарт-контракт реализует продажу токена ERC-721 (nft) с применением аукциона по типу голландского.
 * Голландский аукцион подразумевает уменьшение стоимости предмета с течением времени.
 * Аукцион начинается с максимально установленной цены.
 * Собранные средства перемещаются на установленный адрес wallet.
 * @dev Роли смарт-контракта:
 * - DEFAULT_ADMIN_ROLE. Может изменять адрес кошелька для вывода собранных с продажи средств.
 *      Может управлять настройкой стартовой ценой за нфт.
 * - AUCTIONEER_ROLE. Может создавать и стартовать аукцион через вызов функции start() или отменять его cancel()
 */
contract DutchAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");

    uint256 private constant _DEFAULT_STARTING_PRICE = 1000 ether;
    uint256 private constant _MIN_AUCTION_TIME = 1 hours;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 startingPrice;
        uint256 discountRatePerSecond;
        address auctioneer;
    }

    Auction private _auction;
    address private _wallet;
    uint256 private _startingPrice = _DEFAULT_STARTING_PRICE;

    event AuctionStarted(Auction auction);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(Auction auction, address indexed winner, uint256 value);
    event WalletSet(address wallet);
    event StartingPriceSet(uint256 startingPrice);

    error AuctionNotStarted();
    error AuctionHasAlreadyStarted();
    error DiscountRatePerSecondNotEnough();
    error ValueNotEnough();
    error TransferNativeFailed();
    error AuctionIncorrectStartTime();
    error WalletAddressZero();

    /// @notice Разрешает вызов функции, когда аукцион стартовал
    modifier whenStarted() {
        if (block.timestamp < _auction.start || _auction.start == 0) {
            revert AuctionNotStarted();
        }

        _;
    }

    constructor(address wallet) {
        if (wallet == address(0)) {
            revert WalletAddressZero();
        }

        _wallet = wallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit WalletSet(wallet);
    }

    /**
     * @notice Создает аукцион
     * @param nft Адрес контракта нфт
     * @param tokenId Идентификатор нфт
     * @param startTime Время начала аукциона
     * @param discountRatePerSecond Уменьшение стоимости нфт за секунду
     * @dev Аукцион можно создать заранее, непосредственно указав время его начала
     */
    function start(IERC721 nft, uint256 tokenId, uint256 startTime, uint256 discountRatePerSecond)
        external
        onlyRole(AUCTIONEER_ROLE)
    {
        if (_auction.start != 0) {
            revert AuctionHasAlreadyStarted();
        }

        if (startTime < block.timestamp) {
            revert AuctionIncorrectStartTime();
        }

        if (discountRatePerSecond <= _startingPrice / _MIN_AUCTION_TIME) {
            /// Уменьшение стоимости до 0 нфт не должно быть быстрее,
            /// чем минимально установленное время _MIN_AUCTION_TIME
            revert DiscountRatePerSecondNotEnough();
        }

        /// Переводим нфт на смарт-контракт аукциона
        nft.transferFrom(msg.sender, address(this), tokenId);

        /// Создаем запись об аукционе
        _auction = Auction({
            nft: nft,
            tokenId: tokenId,
            start: startTime,
            startingPrice: _startingPrice,
            discountRatePerSecond: discountRatePerSecond,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Отменяет аукцион
     * @dev Отменить аукцион может только аукционер
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;

        /// Очистить информацию об аукционе
        delete _auction;

        /// Вернуть nft аукционисту
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Заканчивает аукцион
     * @dev Закончить аукцион может любой адрес
     */
    function finish() external payable whenStarted {
        uint256 price = _getPrice();

        /// Вернуть транзакцию, если оплаты за нфт недостаточно
        if (msg.value < price) {
            revert ValueNotEnough();
        }

        /// Очищаем данные о прошедшем аукционе
        Auction memory auction = _auction;
        delete _auction;

        if (price == 0) {
            /// Если стоимость нфт равняется 0
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Отправить nft победителю
            auction.nft.transferFrom(address(this), msg.sender, auction.tokenId);

            /// Отправить плату на кошелек протокола
            _transferNative(_wallet, price);

            /// Отправить оставшиеся излишки обратно победителю аукциона
            _transferNative(msg.sender, msg.value - price);
        }

        emit AuctionFinished(auction, msg.sender, msg.value);
    }

    /// @notice Возвращает информацию о стоимости нфт в данный момент времени
    function getPrice() external view whenStarted returns (uint256) {
        return _getPrice();
    }

    /// @notice Вернуть стоимость нфт
    function _getPrice() private view returns (uint256) {
        Auction memory auction = _auction;

        /// Считаем разницу между текущим временем и началом аукциона в секундах
        uint256 elapsedTime = block.timestamp - auction.start;

        /// Считаем размер скидки за прошедшее время
        uint256 discountValue = elapsedTime * auction.discountRatePerSecond;

        /// Интерактив: Здесь можно усложнить и реализовать резервную цену, ниже которой нфт не может стоить
        /// Попробуй реализовать самостоятельно. Не забудь проверить условие в функции finish() и добавить тесты

        /// Если размер скидки больше стартовой стоимости, вернуть 0
        return auction.startingPrice > discountValue ? auction.startingPrice - discountValue : 0;
    }

    /// @notice Возвращает начальную стоимость нфт для каждого нового аукциона
    function getStartingPrice() external view returns (uint256) {
        return _startingPrice;
    }

    /**
     * @notice Позволяет изменить начальную стоимость нфт для каждого нового аукциона
     * @param startingPrice Новая начальная стоимость нфт
     * @dev Только DEFAULT_ADMIN_ROLE
     */
    function setStartingPrice(uint256 startingPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _startingPrice = startingPrice;

        emit StartingPriceSet(startingPrice);
    }

    /// @notice Возвращает информацию по аукциону
    function getAuction() external view returns (Auction memory) {
        return _auction;
    }

    /// @notice Возвращает адрес кошелька для вывода собранных с продажи средств
    function getWallet() external view returns (address) {
        return _wallet;
    }

    /**
     * @notice Позволяет изменить кошелек для вывода собранных с продажи средств
     * @param wallet Новое адрес кошелька
     * @dev Только DEFAULT_ADMIN_ROLE
     */
    function setWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _wallet = wallet;

        emit WalletSet(wallet);
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}

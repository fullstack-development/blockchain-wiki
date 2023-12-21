// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Английский аукцион
 * @notice Смарт-контракт реализует продажу токена ERC-721 (nft) с применением аукциона по типу английского.
 * Английский аукцион подразумевает повышение стоимости предмета с каждой новой ставкой. Аукцион ограничен по времени.
 * Собранные средства перемещаются на установленный адрес wallet.
 * @dev Роли смарт-контракта:
 * - DEFAULT_ADMIN_ROLE. Может изменять адрес кошелька для вывода собранных с продажи средств.
 *      Может управлять настройкой продолжительности аукциона.
 * - AUCTIONEER_ROLE. Может создавать и стартовать аукцион через вызов функции start() или отменять его cancel()
 */
contract EnglishAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");
    uint256 private constant _DEFAULT_AUCTION_DURATION = 10 days;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 duration;
        address auctioneer;
    }

    struct HighestBid {
        address account;
        uint256 value;
    }

    Auction private _auction;
    HighestBid private _highestBid;
    uint256 _auctionDuration = _DEFAULT_AUCTION_DURATION;
    address private _wallet;

    event AuctionStarted(Auction auction);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(Auction auction, HighestBid highestBid);
    event Bid(address indexed account, uint256 value);
    event AuctionDurationSet(uint256 auctionDuration);
    event WalletSet(address wallet);

    error AuctionNotStarted();
    error AuctionNotFinished();
    error AuctionHasAlreadyStarted();
    error AuctionHasAlreadyFinished();
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

    /// @notice Разрешает вызов функции, когда аукцион закончился
    modifier whenFinished() {
        uint256 auctionFinish = _auction.start + _auction.duration;

        if (block.timestamp < auctionFinish) {
            revert AuctionNotFinished();
        }

        _;
    }

    /// @notice Разрешает вызов функции, когда аукцион не закончился
    modifier whenNotFinished() {
        uint256 auctionFinish = _auction.start + _auction.duration;

        if (block.timestamp >= auctionFinish) {
            revert AuctionHasAlreadyFinished();
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
     * @dev Аукцион можно создать заранее, непосредственно указав время его начала
     */
    function start(IERC721 nft, uint256 tokenId, uint256 startTime) external onlyRole(AUCTIONEER_ROLE) {
        if (_auction.start != 0) {
            revert AuctionHasAlreadyStarted();
        }

        if (startTime < block.timestamp) {
            revert AuctionIncorrectStartTime();
        }

        /// Переводим нфт на смарт-контракт аукциона
        nft.transferFrom(msg.sender, address(this), tokenId);

        /// Создаем запись об аукционе
        _auction = Auction({
            nft: nft,
            tokenId: tokenId,
            start: startTime,
            duration: _auctionDuration,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Позволяет сделать ставку
     * @dev В качестве ставки принимается нативная валюта блокчейна
     */
    function bid() external payable whenStarted whenNotFinished {
        HighestBid memory highestBid = _highestBid;

        /// Каждая новая ставка должна быть больше предыдущей
        if (msg.value <= highestBid.value) {
            revert ValueNotEnough();
        }

        /// Запись новой ставки
        _highestBid = HighestBid(msg.sender, msg.value);

        /// Возврат прошлому участнику его ставки
        if (highestBid.value > 0) {
            _transferNative(highestBid.account, highestBid.value);
        }

        emit Bid(msg.sender, msg.value);
    }

    /**
     * @notice Отменяет аукцион
     * @dev Отменить аукцион может только аукционер
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;
        HighestBid memory highestBid = _highestBid;

        /// Очистить информацию об аукционе
        _clearAuction();

        if (highestBid.account != address(0)) {
            /// Возврат участнику ставки, если она была сделана
            _transferNative(highestBid.account, highestBid.value);
        }

        /// Вернуть nft аукционисту
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Заканчивает аукцион
     * @dev Закончить аукцион может любой адрес после окончания работы аукциона
     */
    function finish() external whenFinished {
        HighestBid memory highestBid = _highestBid;
        Auction memory auction = _auction;

        /// Очистить информацию об аукционе
        _clearAuction();

        if (highestBid.account == address(0)) {
            /// Если не было не одной ставки, вернуть nft аукционисту
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Отправить плату на кошелек протокола
            _transferNative(_wallet, highestBid.value);

            /// Отправить nft победителю
            auction.nft.transferFrom(address(this), highestBid.account, auction.tokenId);
        }

        emit AuctionFinished(auction, highestBid);
    }

    /// @notice Возвращает информацию о текущей наибольшей ставке
    function getHighestBid() external view returns (HighestBid memory) {
        return _highestBid;
    }

    /// @notice Возвращает время продолжительности работы аукциона по умолчанию
    function getAuctionDuration() external view returns (uint256) {
        return _auctionDuration;
    }

    /**
     * @notice Позволяет изменить время продолжительности работы аукциона
     * @param auctionDuration Новое время продолжительности работы аукциона
     * @dev Только DEFAULT_ADMIN_ROLE
     */
    function setAuctionDuration(uint256 auctionDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _auctionDuration = auctionDuration;

        emit AuctionDurationSet(auctionDuration);
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

    function _clearAuction() private {
        /// Очищаем данные о прошедшем аукционе
        delete _highestBid;
        delete _auction;
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}

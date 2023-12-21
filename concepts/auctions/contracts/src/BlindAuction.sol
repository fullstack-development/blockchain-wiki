// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Слепой аукцион
 * @notice Смарт-контракт реализует продажу токена ERC-721 (nft) с применением аукциона по типу слепого.
 * Слепой аукцион подразумевает сбор ставок в закрытую. Участники аукциона не знают ставки друг друга.
 * Аукцион имеет стадии: сбор скрытых ставок, раскрытие ставок, определение победителя.
 * Собранные средства перемещаются на установленный адрес wallet.
 * Для скрытия ставок участников используется commit-reveal схема
 * @dev Роли смарт-контракта:
 * - DEFAULT_ADMIN_ROLE. Может изменять адрес кошелька для вывода собранных с продажи средств.
 *      Может управлять настройкой продолжительности стадий аукциона.
 * - AUCTIONEER_ROLE. Может создавать и стартовать аукцион через вызов функции start() или отменять его cancel()
 */
contract BlindAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");

    uint256 private constant _DEFAULT_COMMIT_DURATION = 1 days;
    uint256 private constant _DEFAULT_REVEAL_DURATION = 0.5 days;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 commitDuration;
        uint256 revealDuration;
        address auctioneer;
    }

    struct RevealedBid {
        address account;
        uint256 value;
    }

    Auction private _auction;
    uint256 private _commitDuration = _DEFAULT_COMMIT_DURATION;
    uint256 private _revealDuration = _DEFAULT_REVEAL_DURATION;
    address private _wallet;

    mapping(address account => bytes32 blindedBid) private _blindedBids;
    address[] private _auctionParticipants;

    RevealedBid[] private _revealedBids;

    event AuctionStarted(Auction auction);
    event Committed(address indexed account, bytes32 blindedBid);
    event Revealed(address indexed account, uint256 value, bytes32 blindedBid);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(RevealedBid revealedBid);
    event WalletSet(address wallet);
    event CommitDurationSet(uint256 commitDuration);
    event RevealDurationSet(uint256 revealDuration);

    error AuctionNotStarted();
    error AuctionNotCommitStage();
    error AuctionNotRevealStage();
    error AuctionNotFinishStage();
    error AuctionHasAlreadyStarted();
    error BidHasAlreadyCommitted();
    error BidNotCommitted();
    error IncorrectRevealAmount();
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

    /// @notice Разрешает вызов функции, когда аукцион в стадии сбора скрытых ставок
    modifier whenCommit() {
        uint256 commitEnd = _auction.start + _auction.commitDuration;

        if (block.timestamp < _auction.start || block.timestamp > commitEnd) {
            revert AuctionNotCommitStage();
        }

        _;
    }

    /// @notice Разрешает вызов функции, когда аукцион в стадии раскрытия ставок
    modifier whenRevealed() {
        uint256 startReveal = _auction.start + _auction.commitDuration;
        uint256 endReveal = _auction.start + _auction.commitDuration + _auction.revealDuration;

        if (block.timestamp < startReveal || block.timestamp > endReveal) {
            revert AuctionNotRevealStage();
        }

        _;
    }

    /// @notice Разрешает вызов функции, когда аукцион закончился
    modifier whenFinished() {
        uint256 endReveal = _auction.start + _auction.commitDuration + _auction.revealDuration;

        if (block.timestamp < endReveal) {
            revert AuctionNotFinishStage();
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
            commitDuration: _commitDuration,
            revealDuration: _revealDuration,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Позволяет отправить скрытую ставку
     * @param blindedBid Хеш ставки. Получается путем вызова функции generateBlindedBid()
     * @dev Доступно только на стадии commit
     */
    function commit(bytes32 blindedBid) external whenCommit {
        if (_blindedBids[msg.sender] != bytes32(0)) {
            revert BidHasAlreadyCommitted();
        }

        /// Записываем скрытую ставку
        _blindedBids[msg.sender] = blindedBid;
        _auctionParticipants.push(msg.sender);

        emit Committed(msg.sender, blindedBid);
    }

    /**
     * @notice Позволяет раскрыть ставку участника аукциона
     * @dev Доступно только на стадии reveal
     */
    function reveal() external payable whenRevealed {
        bytes32 blindedBid = _blindedBids[msg.sender];

        /// Проверяем, что скрытая ставка была сделана
        if (blindedBid == bytes32(0)) {
            revert BidNotCommitted();
        }

        bytes32 expectedBlindedBid = generateBlindedBid(msg.sender, msg.value);

        /// Проверяем корректность скрытой ставки и присланного количества нативной валюты
        if (blindedBid != expectedBlindedBid) {
            revert IncorrectRevealAmount();
        }

        RevealedBid memory revealedBid = RevealedBid({account: msg.sender, value: msg.value});

        /// Записываем информацию об раскрытой ставке
        _revealedBids.push(revealedBid);

        emit Revealed(msg.sender, msg.value, blindedBid);
    }

    /**
     * @notice Отменяет аукцион
     * @dev Отменить аукцион может только аукционер
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;
        RevealedBid[] memory revealedBids = _revealedBids;

        /// Очистить информацию об аукционе
        _clearAuction();

        /// Проходим по всем раскрытым ставкам
        for (uint256 i = 0; i < revealedBids.length; i++) {
            RevealedBid memory revealedBid = revealedBids[i];

            /// Делаем возврат по раскрытой ставке
            _transferNative(revealedBid.account, revealedBid.value);
        }

        /// Вернуть nft аукционисту
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Завершает аукцион
     * @dev Для участия в финальном определения победителя обязательно раскрытие ставки пользователем.
     * При равных суммах ставок у двух и более участников побеждает тот,
     * кто раньше сделал раскрытие ставки
     */
    function finish() external whenFinished {
        RevealedBid memory winnerRevealedBid;
        Auction memory auction = _auction;

        /// Проходим по всем раскрытым ставкам
        for (uint256 i = 0; i < _revealedBids.length; i++) {
            RevealedBid memory revealedBid = _revealedBids[i];

            /// Если новая раскрытая ставка больше всех предыдущих ставок
            if (revealedBid.value > winnerRevealedBid.value) {
                /// Делаем возврат ставки прошлому победителю
                _transferNative(winnerRevealedBid.account, winnerRevealedBid.value);

                /// Сохраняем новую ставку
                winnerRevealedBid = revealedBid;
            } else {
                /// Делаем возврат раскрытой ставки, которая меньше ставки найденного победителя
                _transferNative(revealedBid.account, revealedBid.value);
            }
        }

        /// Очистить информацию об аукционе
        _clearAuction();

        if (winnerRevealedBid.account == address(0)) {
            /// Если не было не одной ставки, вернуть nft аукционисту
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Отправить плату на кошелек протокола
            _transferNative(_wallet, winnerRevealedBid.value);

            /// Отправить nft победителю
            auction.nft.transferFrom(address(this), winnerRevealedBid.account, auction.tokenId);
        }

        emit AuctionFinished(winnerRevealedBid);
    }

    /**
     * @notice Генерирует скрытую ставку для участника аукциона
     * @param account Адрес участника аукциона
     * @param value Размер ставки
     */
    function generateBlindedBid(address account, uint256 value) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, value));
    }

    /**
     * @notice Возвращает скрытые ставки для адреса участника аукциона
     * @param account Адрес участника аукциона
     */
    function getBlindedBidByAccount(address account) external view returns (bytes32) {
        return _blindedBids[account];
    }

    /// @notice Возвращает список раскрытых ставок
    function getRevealedBids() external view returns (RevealedBid[] memory) {
        return _revealedBids;
    }

    /// @notice Возвращает информацию по аукциону
    function getAuction() external view returns (Auction memory) {
        return _auction;
    }

    /// @notice Возвращает продолжительность стадии commit
    function getCommitDuration() external view returns (uint256) {
        return _commitDuration;
    }

    /**
     * @notice Позволяет установить продолжительность стадии commit
     * @param commitDuration Продолжительность стадии commit
     * @dev Только DEFAULT_ADMIN_ROLE
     */
    function setCommitDuration(uint256 commitDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _commitDuration = commitDuration;

        emit CommitDurationSet(commitDuration);
    }

    /// @notice Возвращает продолжительность стадии reveal
    function getRevealDuration() external view returns (uint256) {
        return _revealDuration;
    }

    /**
     * @notice Позволяет установить продолжительность стадии reveal
     * @param revealDuration Продолжительность стадии reveal
     * @dev Только DEFAULT_ADMIN_ROLE
     */
    function setRevealDuration(uint256 revealDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revealDuration = revealDuration;

        emit RevealDurationSet(revealDuration);
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
        delete _auction;

        /// Очищаем данные о скрытых ставках всех участников
        for (uint256 i = 0; i < _auctionParticipants.length; i++) {
            address participant = _auctionParticipants[i];

            delete _blindedBids[participant];
        }

        /// Очищаем данные об адресах участников аукциона
        delete _auctionParticipants;

        /// Очищаем данные о раскрытых ставках участников аукциона
        delete _revealedBids;
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}

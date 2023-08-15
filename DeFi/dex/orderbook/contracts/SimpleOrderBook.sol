//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error SimpleOrderBook__InsufficientTokenAmount();
error SimpleOrderBook__ZeroTokenAddress();
error SimpleOrderBook__InvalidQuantity();
error SimpleOrderBook__InvalidSpending();
error SimpleOrderBook__OfferIsInactive();
error SimpleOrderBook__SenderIsNotOfferOwner();

/**
 * @notice Контракт ордербука. Контракт не включает механизм сопоставления ордеров. Предполагается, что это делается off-chain
 * @dev Контракт создан в учебных целях. Не использовать на реальных проектах
 */
contract SimpleOrderBook is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Предложение или ордер на обмен. Это может быть покупка или продажа токена
    struct Offer {
        uint256 id;
        address owner;
        address saleToken;
        uint256 amountToSell;
        address buyToken;
        uint256 amountToBuy;
        uint256 timestamp;
    }

    mapping (uint256 => Offer) private _offers;
    uint256 private _lastOfferId;

    modifier canBuy(uint256 _id) {
        if (!isOfferActive(_id)) {
            revert SimpleOrderBook__OfferIsInactive();
        }
        _;
    }

    modifier canCancel(uint _id) {
        if (!isOfferActive(_id)) {
            revert SimpleOrderBook__OfferIsInactive();
        }

        if (getOwnerById(_id) != msg.sender) {
            revert SimpleOrderBook__SenderIsNotOfferOwner();
        }
        _;
    }

    event OfferCreated(uint256 indexed offerId, Offer offer);
    event OfferClosed(uint256 indexed offerId, Offer offer);
    event OfferPartiallyClosed(uint256 indexed offerId, Offer offer);
    event OfferCanceled(uint256 indexed offerId, Offer offer);

    /**
     * @notice Создание ордера
     * @param _saleToken Адрес токена для продажи
     * @param _amountToSell Сумма токена продажи
     * @param _buyToken Адрес токена для покупки
     * @param _amountToBuy Сумма токена покупки
     */
    function createOffer(address _saleToken, uint256 _amountToSell, address _buyToken, uint256 _amountToBuy) external nonReentrant {
        if (_saleToken == address(0) && _buyToken == address(0)) {
            revert SimpleOrderBook__ZeroTokenAddress();
        }

        if (_amountToSell == 0 || _amountToBuy == 0) {
            revert SimpleOrderBook__InsufficientTokenAmount();
        }

        uint256 nextId = _getNextOfferId();

        Offer memory newOffer = Offer(
            nextId,
            msg.sender,
            _saleToken,
            _amountToSell,
            _buyToken,
            _amountToBuy,
            block.timestamp
        );

        _offers[nextId] = newOffer;
        IERC20(_saleToken).safeTransferFrom(msg.sender, address(this), _amountToSell);

        emit OfferCreated(nextId, newOffer);
    }

    /**
     * @notice Исполнение ордера
     * @param _id Идентификатор ордера
     * @param _quantity Количество токена для исполнения ордера
     */
    function buy(uint256 _id, uint256 _quantity) external canBuy(_id) nonReentrant {
        Offer memory offer = _offers[_id];

        uint256 spending = (_quantity * offer.amountToBuy) / offer.amountToSell;

        if (_quantity == 0 || _quantity > offer.amountToSell) {
            revert SimpleOrderBook__InvalidQuantity();
        }

        if (spending == 0 || spending > offer.amountToBuy) {
            revert SimpleOrderBook__InvalidSpending();
        }

        _offers[_id].amountToSell = offer.amountToSell - _quantity;
        _offers[_id].amountToBuy = offer.amountToBuy - spending;

        if (_offers[_id].amountToSell == 0) {
          delete _offers[_id];

          emit OfferClosed(_id, offer);
        }
        else {
            emit OfferPartiallyClosed(_id, _offers[_id]);
        }

        IERC20(offer.buyToken).safeTransferFrom(msg.sender, offer.owner, spending);
        IERC20(offer.saleToken).transfer(msg.sender, _quantity);
    }

    /**
     * @notice Отмена ордера
     * @param _id Идентификатор ордера
     */
    function cancel(uint256 _id) external canCancel(_id) nonReentrant {
        Offer memory offer = _offers[_id];

        delete _offers[_id];

        IERC20(offer.saleToken).safeTransferFrom(address(this), msg.sender, offer.amountToSell);

        emit OfferCanceled(_id, offer);
    }

    /**
     * @notice Получение ордера по идентификатору
     * @param _id Идентификатор ордера
     */
    function getOfferById(uint256 _id) external view returns (Offer memory) {
        return _offers[_id];
    }

    /**
     * @notice Получение создателя ордера по идентификатору
     * @param _id Идентификатор ордера
     * @return Адрес владельца ордера
     */
    function getOwnerById(uint256 _id) public view returns (address) {
        return _offers[_id].owner;
    }

    /**
     * @notice Проверка актуальности ордера
     * @param _id Идентификатор ордера
     * @return True, если ордер активен, иначе - false
     */
    function isOfferActive(uint256 _id) public view returns (bool) {
        return _offers[_id].timestamp > 0;
    }

    function _getNextOfferId() private returns (uint256) {
        _lastOfferId++;

        return _lastOfferId;
    }
}
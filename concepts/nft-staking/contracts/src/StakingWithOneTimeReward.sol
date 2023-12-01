// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Контракт стейкинга NFT c разовым вознаграждением после получения NFT обратно
 * @notice Контракт принимает NFT для хранения и
 * позволяет через определенный срок вернуть NFT обратно с вознаграждением в ERC-20 токене
 */
contract StakingWithOneTimeReward is Ownable, ERC721Holder {
    using SafeERC20 for IERC20;

    /// @notice NFT, которая может быть застейкана
    IERC721 private _nft;

    /// @notice Токен для выплаты вознаграждения
    IERC20 private _rewardToken;

    /// @notice Время стейка NFT
    uint256 private _stakeDuration = 30 days;

    /// @notice Сумма вознаграждения за полный период стейка одной NFT
    uint256 private _rewardAmountPerNft;

    struct StakeInfo {
        address owner;
        uint256 start;
        uint256 duration;
    }

    /// @notice Информация по стейку каждой NFT
    mapping(uint256 tokenId => StakeInfo stakeInfo) private _stakes;

    event Staked(address account, uint256 tokenId);
    event Unstaked(address account, uint256 tokenId);
    event Claimed(address claimer, uint256 value);

    error StakeIsNotExist();
    error NotStaker();
    error StakingTimeNotExpired();

    /// @dev Модификатор проверки возможности забрать NFT
    modifier checkUnstake(uint256 tokenId) {
        StakeInfo memory stakeInfo = _stakes[tokenId];

        if (stakeInfo.start == 0) {
            revert StakeIsNotExist();
        }

        if (msg.sender != stakeInfo.owner) {
            revert NotStaker();
        }

        /// Проверка, что время стейка истекло и можно забрать NFT
        if (block.timestamp <= stakeInfo.start + stakeInfo.duration) {
            revert StakingTimeNotExpired();
        }

        _;
    }

    constructor (IERC721 nft, IERC20 rewardToken, uint256 rewardAmountPerNft) Ownable(msg.sender) {
        _nft = nft;
        _rewardToken = rewardToken;

        _rewardAmountPerNft = rewardAmountPerNft;
    }

    /**
     * @notice Позволяет передать NFT на хранение контракту
     * @param tokenId Идентификатор NFT
     * @dev Перед вызовов владелец должен дать approve()
     */
    function stake(uint256 tokenId) external {
        /// Перевод NFT от владельца контракту
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Запись информации о стейке NFT
        _stakes[tokenId] = StakeInfo({
            owner: msg.sender,
            start: block.timestamp,
            duration: _stakeDuration
        });

        emit Staked(msg.sender, tokenId);
    }

    /**
     * @notice Позволяет забрать NFT владельцу
     * @param tokenId Идентификатор NFT
     * @dev Проверка владельца в модификаторе checkUnstake()
     */
    function unstake(uint256 tokenId) external checkUnstake(tokenId) {
        /// Отправляет вознаграждение владельцу NFT
        _claimReward(msg.sender);

        /// Перевод NFT от контракта владельцу
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        /// Удаление данных о стейке
        delete _stakes[tokenId];

        emit Unstaked(msg.sender, tokenId);
    }

    function _claimReward(address account) private {
        uint256 value = _rewardAmountPerNft;

        _rewardToken.safeTransfer(account, value);

        emit Claimed(account, value);
    }

    /// @notice Возвращает сумму вознаграждения за NFT
    function getRewardAmountPerNft() external view returns (uint256) {
        return _rewardAmountPerNft;
    }

    /// @notice Возвращает адрес NFT коллекции
    function getNftAddress() external view returns (address) {
        return address(_nft);
    }

    /// @notice Возвращает адрес токена вознаграждения
    function getRewardTokenAddress() external view returns (address) {
        return address(_rewardToken);
    }

    /// @notice Возвращает время стейка для получения вознаграждения
    function getStakeDuration() external view returns (uint256) {
        return _stakeDuration;
    }
}

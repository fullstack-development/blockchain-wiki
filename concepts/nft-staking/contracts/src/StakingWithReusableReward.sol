// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Контракт стейкинга NFT с возможностью забирать вознаграждение в любое время
 * @notice Контракт принимает NFT для хранения и
 * позволяет в любой момент владельцу вернуть NFT обратно.
 * @dev Вознаграждения начисляется каждую единицу времени пропорционально годовой сумме вознаграждения
 */
contract StakingWithReusableReward is Ownable, ERC721Holder {
    using SafeERC20 for IERC20;

    /// @notice Точность вычислений
    uint256 public constant MULTIPLIER = 1 ether;

    /**
     * A four-century period will be missing 3 of its 100 Julian leap years, leaving 97.
     * So the average year has 365 + 97/400 = 365.2425 days
     * ERROR(Julian): -0.0078
     * ERROR(Gregorian): -0.0003
     * A day = 24 * 60 * 60 sec = 86400 sec
     * 365.2425 * 86400 = 31556952.0
     */
    uint256 public constant SECS_PER_YEAR = 31_556_952; // 365.2425 days

    /// @notice NFT, которая может быть застейкана
    IERC721 private _nft;

    /// @notice Токен для выплаты вознаграждения
    IERC20 private _rewardToken;

    /// @notice Годовая сумма вознаграждения за одну NFT
    uint256 private _annualRewardAmountPerNft;

    struct RewardInfo {
        uint256 lastTimeRewardUpdated;
        uint256 rewardAmount;
        uint256 tokenBalance;
    }

    /// @notice Информация по стейку каждой NFT
    mapping(uint256 tokenId => address stakeholder) private _stakes;

    /// @notice Информация по накоплению вознаграждения
    mapping(address stakeholder => RewardInfo rewardInfo) private _stakerRewardInfo;

    event Staked(address account, uint256 tokenId);
    event Unstaked(address account, uint256 tokenId);
    event Claimed(address claimer, uint256 value);

    error StakeIsNotExist();
    error NotStaker();

    /// @dev Модификатор проверки возможности забрать NFT
    modifier checkUnstake(uint256 tokenId) {
        address stakeholder = _stakes[tokenId];

        if (stakeholder == address(0)) {
            revert StakeIsNotExist();
        }

        if (msg.sender != stakeholder) {
            revert NotStaker();
        }

        _;
    }

    /// @dev Модификатор обновления суммы вознаграждения
    modifier updateReward(address stakeholder) {
        _updateReward(stakeholder);

        _;
    }

    constructor (IERC721 nft, IERC20 rewardToken, uint256 annualRewardAmountPerNft) Ownable(msg.sender) {
        _nft = nft;
        _rewardToken = rewardToken;

        _annualRewardAmountPerNft = annualRewardAmountPerNft;
    }

    /**
     * @notice Позволяет передать NFT на хранение контракту
     * @param tokenId Идентификатор NFT
     * @dev Перед вызовов владелец должен дать approve().
     * Проверяет и фиксирует вознаграждение на момент вызова функции в модификаторе updateReward()
     */
    function stake(uint256 tokenId) external updateReward(msg.sender) {
        /// Перевод NFT от владельца контракту
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Сохранение информации о стейке NFT
        _stakes[tokenId] = msg.sender;

        /// Сохранение информации о накопление вознаграждения
        _stakerRewardInfo[msg.sender].tokenBalance += 1;
        _stakerRewardInfo[msg.sender].lastTimeRewardUpdated = block.timestamp;

        emit Staked(msg.sender, tokenId);
    }

    /**
     * @notice Позволяет забрать NFT владельцу
     * @param tokenId Идентификатор NFT
     * @dev Проверяет и фиксирует вознаграждение на момент вызова функции в модификаторе updateReward()
     */
    function unstake(uint256 tokenId) external updateReward(msg.sender) {
        _unstake(tokenId);
    }

    /// @dev Проверка владельца в модификаторе checkUnstake().
    function _unstake(uint256 tokenId) private checkUnstake(tokenId) {
        /// Перевод NFT от контракта владельцу
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        /// Удаление данных о стейке
        delete _stakes[tokenId];

        /// Изменение информации для начисления вознаграждения
        _stakerRewardInfo[msg.sender].tokenBalance -= 1;

        emit Unstaked(msg.sender, tokenId);
    }

    /**
     * @notice Отправляет вознаграждение владельцу NFT
     * @param stakeholder Адрес владельца NFT
     * @dev Проверяет и фиксирует вознаграждение на момент вызова функции в модификаторе updateReward()
     */
    function claimReward(address stakeholder) external updateReward(stakeholder) {
        _claimReward(stakeholder);
    }

    /// @dev Отправка накопленного вознаграждения
    function _claimReward(address stakeholder) private {
        RewardInfo memory rewardInfo = _stakerRewardInfo[stakeholder];

        if (rewardInfo.rewardAmount > 0) {
            /// Отправка накопленного вознаграждения
            _rewardToken.safeTransfer(stakeholder, rewardInfo.rewardAmount);

            emit Claimed(stakeholder, rewardInfo.rewardAmount);
        }
    }

    /**
     * @notice Позволяет забрать NFT владельцу и получить вознаграждение в одной транзакции
     * @param tokenId Идентификатор NFT
     * @dev Проверяет и фиксирует вознаграждение на момент вызова функции в модификаторе updateReward()
     */
    function unstakeWithClaimReward(uint256 tokenId) external updateReward(msg.sender) {
        _unstake(tokenId);
        _claimReward(msg.sender);
    }

    /// @dev Обновление информации о накопленном вознаграждение
    function _updateReward(address stakeholder) private {
        RewardInfo memory rewardInfo = _stakerRewardInfo[stakeholder];

        if (rewardInfo.tokenBalance > 0) {
            /// Рассчитываем вознаграждение
            uint256 rewardAmount = _calculateReward(
                rewardInfo.tokenBalance,
                rewardInfo.lastTimeRewardUpdated,
                block.timestamp
            );

            /// Обновляем время последнего расчета суммы вознаграждения
            _stakerRewardInfo[stakeholder].lastTimeRewardUpdated = block.timestamp;

            /// Добавляем сумму вознаграждения к уже накопленному
            _stakerRewardInfo[stakeholder].rewardAmount = rewardInfo.rewardAmount + rewardAmount;
        }
    }

    /// @dev Расчет суммы вознаграждения за определенный период времени
    function _calculateReward(uint256 nftAmount, uint256 startTime, uint256 endTime)
        private
        view
        returns (uint256 rewardAmount)
    {
        /// Количество NFT * годовую сумму вознаграждения
        uint256 rewardPerYear = (nftAmount * _annualRewardAmountPerNft) / MULTIPLIER;

        /// Сумма за определенный период времени
        rewardAmount = (rewardPerYear * (endTime - startTime)) / SECS_PER_YEAR;
    }

    /// @notice Возвращает годовую сумму вознаграждения за NFT
    function getAnnualRewardAmountPerNft() external view returns (uint256) {
        return _annualRewardAmountPerNft;
    }

    /// @notice Возвращает адрес NFT коллекции
    function getNftAddress() external view returns (address) {
        return address(_nft);
    }

    /// @notice Возвращает адрес токена вознаграждения
    function getRewardTokenAddress() external view returns (address) {
        return address(_rewardToken);
    }

    /// @notice Возвращает информацию о накопленном вознаграждении
    function getRewardInfo(address stakeholder) external view returns (RewardInfo memory) {
        return _stakerRewardInfo[stakeholder];
    }
}

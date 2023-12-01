// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**
 * @title Простой контракт стейкинга NFT
 * @notice Контракт принимает NFT для хранения и
 * позволяет в любой момент владельцу вернуть NFT обратно
 */
contract SimpleStaking is Ownable, ERC721Holder {
    /// @notice NFT, которая может быть застейкана
    IERC721 private _nft;

    /// @notice Хранение адресов владельцев для застейканных NFT
    mapping(uint256 tokenId => address stakeholder) private _stakes;

    /// @notice Хранение количества застейканных NFT для каждого адреса
    mapping(address stakeholder => uint256 counter) private _stakedNftBalance;

    event Staked(address account, uint256 tokenId);
    event Unstaked(address account, uint256 tokenId);

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

    constructor (IERC721 nft) Ownable(msg.sender) {
        _nft = nft;
    }

    /**
     * @notice Позволяет передать NFT на хранение контракту
     * @param tokenId Идентификатор NFT
     * @dev Перед вызовов владелец должен дать approve()
     */
    function stake(uint256 tokenId) external {
        /// Перевод NFT от владельца контракту
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Запись данных о владельце
        _stakes[tokenId] = msg.sender;
        _stakedNftBalance[msg.sender] += 1;

        emit Staked(msg.sender, tokenId);
    }

    /**
     * @notice Позволяет забрать NFT владельцу
     * @param tokenId Идентификатор NFT
     * @dev Проверка владельца в модификаторе checkUnstake()
     */
    function unstake(uint256 tokenId) external checkUnstake(tokenId) {
        /// Перевод NFT от контракта владельцу
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        /// Удаление данных о владельце
        delete _stakes[tokenId];
        _stakedNftBalance[msg.sender] -= 1;

        emit Unstaked(msg.sender, tokenId);
    }

    /**
     * @notice Позволяет проверить застейкана ли NFT
     * @param tokenId Идентификатор NFT
     * @return Адрес владельца NFT
     */
    function getStakerByTokenId(uint256 tokenId) external view returns (address) {
        return _stakes[tokenId];
    }

    /**
     * @notice Позволяет получить количество застейканных NFT владельцем
     * @param stakeholder Адрес владельца NFT
     */
    function getStakedNftBalance(address stakeholder) external view returns (uint256) {
        return _stakedNftBalance[stakeholder];
    }

    /// @notice Возвращает адрес NFT коллекции
    function getNftAddress() external view returns (address) {
        return address(_nft);
    }
}

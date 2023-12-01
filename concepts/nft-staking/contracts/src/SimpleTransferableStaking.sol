// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface ILpNft is IERC721 {
    function mint(address account, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
}

/**
 * @title Простой контракт стейкинга NFT
 * с возможностью передать право владения застейканной NFT
 * @notice Контракт принимает NFT для хранения и
 * позволяет в любой момент владельцу вернуть NFT обратно или передать право владения
 * @dev Право владения подтверждается через владения lp nft,
 * которая выдается в момент вызова stake() и сжигается в момент вызова unstake()
 */
contract SimpleTransferableStaking is Ownable, ERC721Holder {
    /// @notice NFT, которая может быть застейкана
    IERC721 private _nft;

    /// @notice NFT, которая выдается в обмен застейканной NFT
    ILpNft private _lpNft;

    event Staked(address account, uint256 tokenId);
    event Unstaked(address account, uint256 tokenId);

    error StakeIsNotExist();
    error NotStaker();

    /// @dev Модификатор проверки возможности забрать NFT
    modifier checkUnstake(uint256 tokenId) {
        address owner = _nft.ownerOf(tokenId);

        try _lpNft.ownerOf(tokenId) returns (address stakeholder) {
            if (msg.sender != stakeholder) {
                revert NotStaker();
            }
        } catch {
            revert StakeIsNotExist();
        }

        _;
    }

    constructor (IERC721 nft, ILpNft lpNft) Ownable(msg.sender) {
        _nft = nft;
        _lpNft = lpNft;
    }

    /**
     * @notice Позволяет передать NFT на хранение контракту
     * @param tokenId Идентификатор NFT
     * @dev Перед вызовов владелец должен дать approve()
     */
    function stake(uint256 tokenId) external {
        /// Перевод NFT от владельца контракту
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Выдается lp nft
        _lpNft.mint(msg.sender, tokenId);

        emit Staked(msg.sender, tokenId);
    }

    /**
     * @notice Позволяет забрать NFT владельцу
     * @param tokenId Идентификатор NFT
     * @dev Проверка владельца в модификаторе checkUnstake()
     */
    function unstake(uint256 tokenId) external checkUnstake(tokenId) {
        /// Перевод lp NFT от владельца контракту
        _lpNft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Перевод NFT от контракта владельцу
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        /// Сжигается lp nft
        _lpNft.burn(tokenId);

        emit Unstaked(msg.sender, tokenId);
    }

    /// @notice Возвращает адрес NFT коллекции
    function getNftAddress() external view returns (address) {
        return address(_nft);
    }

    /// @notice Возвращает адрес lp NFT коллекции
    function getLpNftAddress() external view returns (address) {
        return address(_lpNft);
    }
}

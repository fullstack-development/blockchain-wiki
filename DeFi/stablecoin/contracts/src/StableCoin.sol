// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Stable coin
 * @notice Этот контракт необходим для имплементации ERC-20 стандарта токена
 * @dev Этот контракт будет управляться отдельным контрактом Engine.
 *
 * Collateral: Экзогенный (ETH и BTC)
 * Minting: Algorithmic
 * Привязка: Pegged
 */
contract StableCoin is ERC20Burnable, Ownable {
    error ZeroAmount();
    error InsufficientBalance();
    error ZeroAddress();

    constructor() ERC20("Stable coin", "DSC") Ownable() {}

    function burn(uint256 amount) public override onlyOwner {
        if (amount <= 0) {
            revert ZeroAmount();
        }

        uint256 balance = balanceOf(msg.sender);
        if (balance < amount) {
            revert InsufficientBalance();
        }

        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (amount <= 0) {
            revert ZeroAmount();
        }

        _mint(to, amount);

        return true;
    }
}

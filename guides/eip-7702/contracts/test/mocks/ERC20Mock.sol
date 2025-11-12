// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 initialDecimals) ERC20(name, symbol) {
        _decimals = initialDecimals;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

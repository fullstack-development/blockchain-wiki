// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) ERC20("ERC20Mock", "ErcM-20") {
        _decimals = decimals_;
    }

	function mint(address to, uint256 amount) external {
        _mint(to, amount);
	}

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

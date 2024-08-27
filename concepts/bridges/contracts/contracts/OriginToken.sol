// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OriginToken is ERC20 {
    constructor() ERC20("OriginToken", "OT") {
        _mint(msg.sender, 100e18);
    }

    function mint(address recipient) external {
        _mint(recipient, 100e18);
    } 
}

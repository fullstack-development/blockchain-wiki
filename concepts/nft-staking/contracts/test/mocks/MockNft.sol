// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockERC721} from "forge-std/mocks/MockERC721.sol";

contract MockNft is MockERC721 {
    constructor () {
        initialize("MockToken", "MT");
    }

    function mint(address account, uint256 tokenId) external {
        _mint(account, tokenId);
    }
}
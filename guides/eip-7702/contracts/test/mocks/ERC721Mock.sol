// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor() ERC721("ERC721Mock", "MT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

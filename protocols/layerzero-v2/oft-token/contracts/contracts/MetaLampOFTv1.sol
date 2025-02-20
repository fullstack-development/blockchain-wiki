// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract MetaLampOFTv1 is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}

    function claim() external {
        _mint(msg.sender, 100e18);
    }

    function mintTo(address _to, uint256 _amount) external onlyOwner() {
        _mint(_to, _amount);
    }

    function burnFrom(address _to, uint256 _amount) external onlyOwner() {
        _burn(_to, _amount);
    }
}

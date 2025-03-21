// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { MetaLampOFTv1 } from "../MetaLampOFTv1.sol";

// @dev WARNING: This is for testing purposes only
contract MetaLampOFTv1Mock is MetaLampOFTv1 {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) MetaLampOFTv1(_name, _symbol, _lzEndpoint, _delegate) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}

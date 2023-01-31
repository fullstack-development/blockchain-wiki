// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SupplyStorage is Ownable {
    address private _logic;
    uint256 private _totalSupply;

    modifier onlyLogic() {
        if (_msgSender() != _logic) {
            revert OnlyLogic(_msgSender());
        }

        _;
    }

    event TotalSupplySet(uint256 newTotalSupply);
    event LogicSet(address newLogic);

    error OnlyLogic(address sender);

    constructor(address logic) {
        _logic = logic;
    }

    function getTotalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setTotalSupply(uint256 _newTotalSupply) onlyLogic() external {
        _totalSupply = _newTotalSupply;

        emit TotalSupplySet(_newTotalSupply);
    }

    function setLogic(address _newLogic) external onlyOwner() {
        _logic = _newLogic;

        emit LogicSet(_newLogic);
    }
}
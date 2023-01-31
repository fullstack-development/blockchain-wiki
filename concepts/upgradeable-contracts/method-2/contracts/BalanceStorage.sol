// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BalanceStorage is Ownable {
    address private _logic;
    mapping (address => uint256) private _balances;

    modifier onlyLogic() {
        if (_msgSender() != _logic) {
            revert OnlyLogic(_msgSender());
        }

        _;
    }

    event BalanceSet(address account, uint256 newBalance);
    event LogicSet(address newLogic);

    error OnlyLogic(address sender);

    constructor(address logic) {
        _logic = logic;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balances[_account];
    }

    function setBalance(address _account, uint256 _newBalance) onlyLogic() external {
        _balances[_account] = _newBalance;

        emit BalanceSet(_account, _newBalance);
    }

    function setLogic(address _newLogic) external onlyOwner() {
        _logic = _newLogic;

        emit LogicSet(_newLogic);
    }
}
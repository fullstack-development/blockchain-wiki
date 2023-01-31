// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBalanceStorage {
    function balanceOf(address _account) external view returns (uint256);
    function setBalance(address _account, uint256 _newBalance) external;
}

interface ITotalSupplyStorage {
    function getTotalSupply() external view returns (uint256);
    function setTotalSupply(uint256 _newTotalSupply) external;
}

contract TokenLogic {
    IBalanceStorage public balanceStorage;
    ITotalSupplyStorage public totalSupplyStorage;

    event Transfer(address from, address to, uint256 amount);

    error AddressZero();

    constructor(address _balanceStorage, address _totalSupplyStorage) {
        balanceStorage = IBalanceStorage(_balanceStorage);
        totalSupplyStorage = ITotalSupplyStorage(_totalSupplyStorage);
    }

    function totalSupply() public view returns (uint256) {
        // Возвращаем значение из контракта зранилища TotalSupply
        return totalSupplyStorage.getTotalSupply();
    }

    function _mint(address _account, uint256 _amount) internal virtual {
        if (_account == address(0)) {
            revert AddressZero();
        }

        // Записываем новое значение TotalSupply
        uint256 prevTotalSupply = totalSupplyStorage.getTotalSupply();
        totalSupplyStorage.setTotalSupply(prevTotalSupply + _amount);

        // Записываем новое значение balance
        uint256 prevBalance = balanceStorage.balanceOf(_account);
        balanceStorage.setBalance(_account, prevBalance + _amount);

        emit Transfer(address(0), _account, _amount);
    }

    function _burn() internal virtual {/** Аналогичная реализация при помощи доп. хранилищ */}
}
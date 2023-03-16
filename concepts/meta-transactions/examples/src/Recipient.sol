// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BaseRelayRecipient} from "gsn/BaseRelayRecipient.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";

/**
 * @notice Контракт на котором мы хотим организовать работу Gas Station Network
 * @dev Будем использовать версию 2.2.5. Этот контракт создан только в ознакомительных целях.
 * Он не протестирован и не имеет реальной цели
 */
contract Recipient is BaseRelayRecipient, Ownable {
    mapping(address => bool) private _flag;

    event FlagSet(address realSender, address sender);
    event TrustedForwarderSet(address forwarder);

    constructor(address forwarder) {
        // Устанавливаем адрес контракта, которому будет позволено проксировать вызов от имени GSN
        _setTrustedForwarder(forwarder);
    }

    function setFlag(bool value) public {
        _flag[_msgSender()] = value;

        emit FlagSet(msg.sender, _msgSender());
    }

    /**
     * @notice Устанавливает адрес контракта, которому будет позволено проксировать вызов от имени GSN
     * @param forwarder Адрес контракта
     */
    function setTrustedForwarder(address forwarder) external onlyOwner{
        _setTrustedForwarder(forwarder);

        emit TrustedForwarderSet(forwarder);
    }

    function versionRecipient() external override pure returns (string memory) {
        return "2.2.5";
    }

    /// @notice Переопределяем _msgData(). Это необходимо чтобы определять вызовы от контракта Forwarder
    function _msgData() internal view override(Context, BaseRelayRecipient) returns (bytes calldata ret) {
        return super._msgData();
    }

    /// @notice Переопределяем _msgSender(). Это необходимо чтобы определять вызовы от контракта Forwarder
    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address sender) {
        return super._msgSender();
    }
}

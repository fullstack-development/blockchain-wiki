// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BasePaymaster} from "gsn/BasePaymaster.sol";
import "gsn/utils/GsnTypes.sol";

/**
 * @notice Контракт на котором мы будем хранить средства для организации транзакций
 * @dev Будем использовать версию 2.2.5. Этот контракт создан только в ознакомительных целях.
 * Он не протестирован и не имеет реальной цели
 */
contract Paymaster is BasePaymaster {
    address private _target;

    event TargetSet(address target);
    event PostRelayed(address sender);

    error NotTargetContract(address target);

    /**
     * @notice Будет вызывано перед вызовом функции на целевом контракте Recipient
     * @dev Здесь принимается решение, платить за транзакцию или нет.
     * В нашем случае, мы будем платить, если вызов совпадает с нашим адресом целевого контракта
     */
    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata, // signature
        bytes calldata, // approvalData
        uint256 // maxPossibleGas
    ) external view returns (bytes memory context, bool rejectOnRecipientRevert) {
        if (relayRequest.request.to != _target) {
            revert NotTargetContract(relayRequest.request.to);
        }

        return (abi.encode(relayRequest.request.from), true);
    }

    /**
     * @notice Будет вызывано после вызова функции на целевом контракте Recipient
     * @dev Здесь мы уже знаем практически конечную стоимость за газ и можем добавить любую логику
     */
    function postRelayedCall(
        bytes calldata context, // адрес который мы вернули первым параметром из функции preRelayedCall()
        bool, // success
        uint256, // gasUseWithoutPost - стоимость запроса по газу. За исключением стоимости самого газа postRelayedCall)
        GsnTypes.RelayData calldata // relayData
    ) external {
        emit PostRelayed(abi.decode(context, (address)));
    }

    function setTarget(address target) external onlyOwner {
        _target = target;

        emit TargetSet(target);
    }

    function versionPaymaster() external pure returns (string memory) {
        return "2.2.5";
    }
}

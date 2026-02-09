// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { ReadLibConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/readlib/ReadLibBase.sol";
import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { UniswapV3ObserveRead } from "./UniswapV3ObserveRead.sol";

/// @dev Minimal interface to transfer OApp ownership (OApp inherits Ownable).
interface IOwnableOApp {
    function transferOwnership(address newOwner) external;
}

/// @dev Minimal interface to set OApp delegate (for endpoint configuration).
interface IOAppDelegate {
    function setDelegate(address delegate) external;
}

/// @dev Minimal interface to set read channel on lzRead OApp (channel id + active flag).
interface IOAppReadChannel {
    function setReadChannel(uint32 channelId, bool active) external;
}

/**
 * @title LzReadConfig
 * @notice Config contract for lzRead OApp: configures the OApp on the LayerZero endpoint (libraries, DVN, executor)
 *         and sets enforced options on the OApp. Deploy this first, then deploy the OApp with this contract
 *         as owner and delegate so it can perform configuration.
 * @dev Endpoint configuration requires caller to be OApp or its delegate.
 *      OApp configuration (setEnforcedOptions) requires caller to be OApp owner. This contract is both.
 */
contract LzReadConfig is Ownable {
    ILayerZeroEndpointV2 public immutable endpoint;

    /// @notice Parameters for ReadLib config on the endpoint (executor, DVNs). Matches ReadLibConfig fields.
    struct ReadLibConfigParams {
        address executor;
        uint8 requiredDVNCount;
        uint8 optionalDVNCount;
        uint8 optionalDVNThreshold;
        address[] requiredDVNs;
        address[] optionalDVNs;
    }

    /// @notice Parameters for enforced options on the OApp. Pass eid (e.g. readChannel) so one config contract can set options for any OApp that gave it delegate.
    struct EnforcedOptionsParams {
        uint32 eid;
        uint16 msgType;
        bytes options;
    }

    constructor(address _endpoint) Ownable(msg.sender) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
    }

    /**
     * @notice Configures the OApp on the endpoint: send/receive libraries and ReadLib config.
     * @param _oapp Address of the lzRead OApp. This contract must be the OApp's owner and delegate.
     * @param _readChannel Read channel ID for this OApp (can differ per OApp).
     * @param _readLib Message library address for read (e.g. ReadLib1002 for the target chain).
     * @param _libConfig Executor, required/optional DVNs and threshold for ReadLib.
     * @param _receiveGracePeriod Grace period (seconds) for receive library activation; 0 = immediate.
     */
    function configureEndpoint(
        address _oapp,
        uint32 _readChannel,
        address _readLib,
        ReadLibConfigParams calldata _libConfig,
        uint256 _receiveGracePeriod
    ) public onlyOwner {
        endpoint.setSendLibrary(_oapp, _readChannel, _readLib);
        endpoint.setReceiveLibrary(_oapp, _readChannel, _readLib, _receiveGracePeriod);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({
            eid: _readChannel,
            configType: 1, // LZ_READ_LID_CONFIG_TYPE
            config: abi.encode(ReadLibConfig({
                executor: _libConfig.executor,
                requiredDVNCount: _libConfig.requiredDVNCount,
                optionalDVNCount: _libConfig.optionalDVNCount,
                optionalDVNThreshold: _libConfig.optionalDVNThreshold,
                requiredDVNs: _libConfig.requiredDVNs,
                optionalDVNs: _libConfig.optionalDVNs
            }))
        });
        endpoint.setConfig(_oapp, _readLib, params);
    }

    /**
     * @notice Sets enforced options on the OApp. Caller must be OApp owner (this contract).
     * @param _oapp Address of the lzRead OApp.
     * @param _params eid (e.g. readChannel), msgType and encoded options. Passing eid lets one configurator set options for any OApp that set it as delegate.
     */
    function setEnforcedOptions(
        address _oapp,
        EnforcedOptionsParams calldata _params
    ) public onlyOwner {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: _params.eid,
            msgType: _params.msgType,
            options: _params.options
        });
        UniswapV3ObserveRead(payable(_oapp)).setEnforcedOptions(enforcedOptions);
    }

    /**
     * @notice Performs full configuration in one call: endpoint (libraries + ReadLib config) and enforced options.
     * @param _oapp Address of the lzRead OApp.
     * @param _readChannel Read channel ID for this OApp.
     * @param _readLib Message library address for read.
     * @param _libConfig Executor and DVN config for the endpoint.
     * @param _receiveGracePeriod Grace period for receive library (0 = immediate).
     * @param _enforced Enforced options (eid, msgType, encoded options bytes).
     */
    function configureFull(
        address _oapp,
        uint32 _readChannel,
        address _readLib,
        ReadLibConfigParams calldata _libConfig,
        uint256 _receiveGracePeriod,
        EnforcedOptionsParams calldata _enforced
    ) external onlyOwner {
        configureEndpoint(_oapp, _readChannel, _readLib, _libConfig, _receiveGracePeriod);
        setEnforcedOptions(_oapp, _enforced);
    }

    /**
     * @notice Sets the delegate for an OApp. Callable only by this config's owner.
     * @dev Use to change who can configure the OApp on the endpoint (e.g. switch delegate to another config).
     *      Caller (this config) must be the OApp's current owner.
     * @param _oapp OApp address.
     * @param _delegate New delegate address (e.g. this config to keep config, or address(0) to remove).
     */
    function setOAppDelegate(address _oapp, address _delegate) external onlyOwner {
        IOAppDelegate(_oapp).setDelegate(_delegate);
    }

    /**
     * @notice Sets the read channel on an OApp. Callable only by this config's owner.
     * @dev Use to change the read channel ID or disable receive (active = false).
     * @param _oapp OApp address (e.g. UniswapV3ObserveRead).
     * @param _channelId Read channel ID.
     * @param _active true = set peer to OApp (receive responses), false = disable (peer bytes32(0)).
     */
    function setOAppReadChannel(address _oapp, uint32 _channelId, bool _active) external onlyOwner {
        IOAppReadChannel(_oapp).setReadChannel(_channelId, _active);
    }

    /**
     * @notice Transfers ownership of an OApp to a new address. Callable only by this config's owner.
     * @dev Use when the OApp owner is this config and you want to pass ownership to another address (e.g. multisig).
     * @param _oapp OApp address (must have this config as current owner).
     * @param _newOwner New owner address.
     */
    function transferOAppOwnership(address _oapp, address _newOwner) external onlyOwner {
        IOwnableOApp(_oapp).transferOwnership(_newOwner);
    }
}

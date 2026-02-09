// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ILayerZeroEndpointV2, MessagingFee, MessagingReceipt, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { AddressCast } from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import { ReadCodecV1, EVMCallRequestV1 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OAppRead } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";

/**
 * @title UniswapV3ObserveRead
 * @notice Contract for querying Uniswap V3 pool observe() on any chain via lzRead and receiving the result on the deployment chain (origin).
 * @dev Deploy on any chain (origin). Configure targetEid and targetPoolAddress to read observe(uint32[] secondsAgos) from a pool on another chain (data chain).
 */
interface IUniswapV3PoolObserve {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

contract UniswapV3ObserveRead is OAppRead, OAppOptionsType3 {
    /// @notice Emitted when observe() result is received from the target chain.
    event ObserveResult(int56[] tickCumulatives, uint160[] secondsPerLiquidityCumulativeX128s);

    /// @notice Message type ID used in OApp options for this read flow.
    uint8 private constant READ_MSG_TYPE = 1;
    /// @notice Read channel ID: identifies the lzRead channel used to send requests and receive responses (must match LayerZero config).
    uint32 public READ_CHANNEL;

    /// @notice LayerZero EID of the chain where the Uniswap V3 pool lives (data chain).
    uint32 public immutable targetEid;
    /// @notice Uniswap V3 pool address on the target chain.
    address public immutable targetPoolAddress;

    constructor(
        address _endpoint,
        uint32 _readChannel,
        uint32 _targetEid,
        address _targetPoolAddress,
        address _config
    ) OAppRead(_endpoint, _config) Ownable(_config) {
        READ_CHANNEL = _readChannel;
        targetEid = _targetEid;
        targetPoolAddress = _targetPoolAddress;
        _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
    }

    /**
     * @notice Builds the read command: call observe(secondsAgos) on the pool on the target chain.
     * @param secondsAgos Array of seconds "ago" (e.g. [3600, 0] for 1-hour TWAP).
     */
    function getCmd(uint32[] calldata secondsAgos) public view returns (bytes memory) {
        bytes memory callData =
            abi.encodeWithSelector(IUniswapV3PoolObserve.observe.selector, secondsAgos);

        EVMCallRequestV1[] memory req = new EVMCallRequestV1[](1);
        req[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: targetPoolAddress,
            callData: callData
        });

        return ReadCodecV1.encode(0, req);
    }

    /**
     * @notice Sends a read request for observe() to the target chain.
     * @param secondsAgos Array of seconds for observe (e.g. [3600, 0]).
     * @param _extraOptions Additional message options (gas, fee).
     */
    function readObserve(
        uint32[] calldata secondsAgos,
        bytes calldata _extraOptions
    ) external payable returns (MessagingReceipt memory receipt) {
        bytes memory cmd = getCmd(secondsAgos);
        return _lzSend(
            READ_CHANNEL,
            cmd,
            combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions),
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
    }

    /**
     * @notice Quotes the fee for the read observe() call.
     */
    function quoteObserve(
        uint32[] calldata secondsAgos,
        bytes calldata _extraOptions,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee) {
        bytes memory cmd = getCmd(secondsAgos);
        return _quote(READ_CHANNEL, cmd, combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions), _payInLzToken);
    }

    /**
     * @notice Handles the observe() response: tickCumulatives and secondsPerLiquidityCumulativeX128s.
     */
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            abi.decode(_message, (int56[], uint160[]));
        emit ObserveResult(tickCumulatives, secondsPerLiquidityCumulativeX128s);
    }

    function setReadChannel(uint32 _channelId, bool _active) public override onlyOwner {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        READ_CHANNEL = _channelId;
    }

    receive() external payable {}
}

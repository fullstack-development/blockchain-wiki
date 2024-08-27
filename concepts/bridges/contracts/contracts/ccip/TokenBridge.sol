// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IToken} from "../interfaces/IToken.sol";

contract TokenBridge is Ownable, CCIPReceiver {
    IToken private _token;
    uint64 private _originTokenChainSelector;
    uint64 private _thisChainSelector;
    address immutable _link;

    enum PayFeesIn {
        Native,
        LINK
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidReceiver();
    error NotEnoughValueSent(uint256 balance, uint256 value);
    error NotEnoughLinkBalance(uint256 balance, uint256 value);
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        bytes data,
        address sender,
        uint256 fees
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address router, IToken token, address link, uint64 originTokenChainSelector, uint64 thisChainSelector)
        Ownable(msg.sender)
        CCIPReceiver(router)
    {
        _token = token;
        _link = link;
        _originTokenChainSelector = originTokenChainSelector;
        _thisChainSelector = thisChainSelector;
    }

    /*//////////////////////////////////////////////////////////////
                           MAIN FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function sendToken(
        uint64 destinationChainSelector,
        address destinationBridgeAddress,
        address destinationChainReceiver,
        address tokenSender,
        uint256 amount,
        PayFeesIn payFeesIn
    ) external payable returns (bytes32 messageId) {
        if (destinationBridgeAddress == address(0) || destinationChainReceiver == address(0)) {
            revert InvalidReceiver();
        }

        (bytes memory sendingData, Client.EVM2AnyMessage memory message, uint256 fee) = prepareMessage(
            destinationChainSelector, destinationBridgeAddress, destinationChainReceiver, amount, payFeesIn
        );

        if (payFeesIn == PayFeesIn.Native && fee > msg.value) {
            revert NotEnoughValueSent(msg.value, fee);
        }

        if (payFeesIn == PayFeesIn.Native) {
            messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(destinationChainSelector, message);
        } else {
            IToken(_link).transferFrom(tokenSender, address(this), fee);
            IToken(_link).approve(i_ccipRouter, fee);

            uint256 linkBalance = IToken(_link).balanceOf(address(this));
            if (fee > linkBalance) {
                revert NotEnoughLinkBalance(linkBalance, fee);
            }
            messageId = IRouterClient(i_ccipRouter).ccipSend(destinationChainSelector, message);
        }

        emit MessageSent(messageId, destinationChainSelector, destinationBridgeAddress, sendingData, tokenSender, fee);

        bool success = _token.transferFrom(tokenSender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }

        if (_thisChainSelector != _originTokenChainSelector) {
            _token.approve(address(this), amount);
            _token.burnFrom(address(this), amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function prepareMessage(
        uint64 destinationChainSelector,
        address destinationBridgeAddress,
        address destinationChainReceiver,
        uint256 amount,
        PayFeesIn payFeesIn
    ) public view returns (bytes memory sendingData, Client.EVM2AnyMessage memory message, uint256 fee) {
        sendingData = abi.encode(destinationChainReceiver, amount);

        message = _buildCCIPMessage(destinationBridgeAddress, payFeesIn, sendingData);

        fee = IRouterClient(i_ccipRouter).getFee(destinationChainSelector, message);
    }

    function getLink() external view returns (address) {
        return _link;
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildCCIPMessage(address destinationBridgeAddress, PayFeesIn payFeesIn, bytes memory data)
        private
        view
        returns (Client.EVM2AnyMessage memory)
    {
        return Client.EVM2AnyMessage({
            receiver: abi.encode(destinationBridgeAddress),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? _link : address(0)
        });
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual override {
        (address destinationChainReceiver, uint256 amount) = abi.decode(message.data, (address, uint256));

        if (_thisChainSelector != _originTokenChainSelector) {
            _token.mint(destinationChainReceiver, amount);
        } else {
            bool success = _token.transfer(destinationChainReceiver, amount);
            if (!success) {
                revert TransferFailed();
            }
            return;
        }
    }

    /*//////////////////////////////////////////////////////////////
                           SERVICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdrawExtra() external onlyOwner {
        (bool succ,) = owner().call{value: address(this).balance}("");
        if (!succ) {
            revert TransferFailed();
        }
    }
}

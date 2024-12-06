// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH} from "erc7579/lib/ModeLib.sol";
import {ExecutionLib, Execution} from "erc7579/lib/ExecutionLib.sol";
import {ERC7579HookBase} from "modulekit/Modules.sol";

contract TokenWhitelist is ERC7579HookBase {
    error EmptyTokensNotAllowed();
    error TokenAlreadyAdded(address token);
    error TokenNotExist(address token);
    error TokenTransferDisallowed(address token);

    mapping(address account => mapping(address token => bool)) private _tokens;
    mapping(address account => bool isInitialized) private _initialized;

    /*//////////////////////////////////////////////////////////////
                              MODULE LOGIC
    //////////////////////////////////////////////////////////////*/

    // region - Module logic

    function _preCheck(address account, address, uint256, bytes calldata msgData)
        internal
        override
        returns (bytes memory hookData)
    {
        CallType callType = CallType.wrap(bytes1(msgData[4:5]));

        if (callType == CALLTYPE_SINGLE) {
            (address target,, bytes calldata callData) = ExecutionLib.decodeSingle(msgData[100:]);

            bytes4 selector = bytes4(callData[:4]);

            _checkSelector(account, target, selector);
        } else if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = ExecutionLib.decodeBatch(msgData[100:]);

            for (uint8 i = 0; i < executions.length; i++) {
                bytes calldata internalData = executions[i].callData;

                bytes4 selector = bytes4(executions[i].callData[:4]);

                _checkSelector(account, executions[i].target, selector);
            }
        }
    }

    function _checkSelector(address account, address target, bytes4 selector) private {
        if (selector == ERC20.transfer.selector || selector == ERC20.approve.selector) {
            if (!isAllowedToken(account, target)) {
                revert TokenTransferDisallowed(target);
            }
        }
    }

    function _postCheck(address account, bytes calldata hookData) internal override {}

    // endregion

    /*//////////////////////////////////////////////////////////////
                          EXECUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - Execution functions

    function updateTokens(address[] memory tokensToAdd, address[] memory tokensToRemove) external {
        if (tokensToAdd.length == 0 && tokensToRemove.length == 0) {
            revert EmptyTokensNotAllowed();
        }

        if (tokensToAdd.length > 0) {
            _addTokens(msg.sender, tokensToAdd);
        }

        if (tokensToRemove.length > 0) {
            _removeTokens(msg.sender, tokensToRemove);
        }
    }

    function _addTokens(address account, address[] memory tokens) private {
        for (uint256 i = 0; i < tokens.length;) {
            if (isAllowedToken(account, tokens[i])) {
                revert TokenAlreadyAdded(tokens[i]);
            }

            _tokens[account][tokens[i]] = true;

            unchecked {
                ++i;
            }
        }
    }

    function _removeTokens(address account, address[] memory tokens) private {
        for (uint256 i = 0; i < tokens.length;) {
            if (!isAllowedToken(account, tokens[i])) {
                revert TokenNotExist(tokens[i]);
            }

            _tokens[account][tokens[i]] = false;

            unchecked {
                ++i;
            }
        }
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                              INSTALLATION
    //////////////////////////////////////////////////////////////*/

    // region - Installation

    function onInstall(bytes calldata data) external {
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);
        _initialized[msg.sender] = true;

        (address[] memory initialTokens) = abi.decode(data, (address[]));

        if (initialTokens.length == 0) {
            revert EmptyTokensNotAllowed();
        }

        _addTokens(msg.sender, initialTokens);
    }

    function onUninstall(bytes calldata data) external {
        if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
        _initialized[msg.sender] = false;

        (address[] memory tokensToRemove) = abi.decode(data, (address[]));

        _removeTokens(msg.sender, tokensToRemove);
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - View functions

    function isAllowedToken(address account, address token) public view returns (bool) {
        return _tokens[account][token];
    }

    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == TYPE_HOOK;
    }

    function isInitialized(address account) public view returns (bool) {
        return _initialized[account];
    }

    // endregion
}

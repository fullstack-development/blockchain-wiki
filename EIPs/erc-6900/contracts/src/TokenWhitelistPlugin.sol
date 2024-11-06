// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    ManifestAssociatedFunction,
    ManifestAssociatedFunctionType,
    ManifestFunction,
    ManifestExecutionHook,
    PluginManifest,
    PluginMetadata,
    SelectorPermission
} from "modular-account-libs/interfaces/IPlugin.sol";
import {BasePlugin} from "modular-account-libs/plugins/BasePlugin.sol";

import {IMultiOwnerPlugin} from "modular-account/plugins/owner/IMultiOwnerPlugin.sol";
import {IStandardExecutor, Call} from "modular-account/interfaces/IStandardExecutor.sol";
import {
    AssociatedLinkedListSet,
    AssociatedLinkedListSetLib,
    SetValue
} from "modular-account/libraries/AssociatedLinkedListSetLib.sol";

import {ITokenWhitelistPlugin} from "src/interfaces/ITokenWhitelistPlugin.sol";

contract TokenWhitelistPlugin is ITokenWhitelistPlugin, BasePlugin {
    using AssociatedLinkedListSetLib for AssociatedLinkedListSet;

    enum FunctionId {
        EXECUTE_FUNCTION,
        EXECUTE_BATCH_FUNCTION
    }

    uint256 internal constant _MANIFEST_DEPENDENCY_INDEX_MULTI_OWNER_USER_OP_VALIDATION = 0;

    string internal constant _NAME = "Token Whitelist Plugin";
    string internal constant _VERSION = "1.0.0";
    string internal constant _AUTHOR = "Metalamp";

    AssociatedLinkedListSet internal _tokens;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EmptyTokensNotAllowed();
    error TokenNotExist(address token);
    error TokenAlreadyAdded(address token);
    error TokenTransferDisallowed(address token);

    /*//////////////////////////////////////////////////////////////
                          VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - Validation

    function preExecutionHook(uint8 functionId, address sender, uint256 value, bytes calldata data)
        external
        view
        override
        returns (bytes memory)
    {
        (sender, value);

        if (functionId == uint8(FunctionId.EXECUTE_FUNCTION)) {
            (address token,, bytes memory innerCalldata) = abi.decode(data[4:], (address, uint256, bytes));

            bytes4 selector;
            assembly {
                selector := mload(add(innerCalldata, 32)) // 0:32 is arr len, 32:36 is selector
            }

            if (selector == ERC20.transfer.selector || selector == ERC20.approve.selector) {
                _isWhitelistedToken(msg.sender, token);
            }
        } else if (functionId == uint8(FunctionId.EXECUTE_BATCH_FUNCTION)) {
            Call[] memory calls = abi.decode(data[4:], (Call[]));

            uint256 length = calls.length;
            for (uint8 i = 0; i < length; i++) {
                bytes memory internalData = calls[i].data;

                // check each function selector that is passed to the executeBatch function
                bytes4 selector;
                assembly {
                    selector := mload(add(internalData, 32))
                }

                if (selector == ERC20.transfer.selector || selector == ERC20.approve.selector) {
                    _isWhitelistedToken(msg.sender, calls[i].target);
                }
            }
        }

        return "";
    }

    function _isWhitelistedToken(address associated, address tokenToCheck) private view {
        if (!isAllowedToken(associated, tokenToCheck)) {
            revert TokenTransferDisallowed(tokenToCheck);
        }
    }

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

    function _addTokens(address associated, address[] memory tokensToAdd) private {
        uint256 length = tokensToAdd.length;

        for (uint256 i = 0; i < length;) {
            if (!_tokens.tryAdd(associated, SetValue.wrap(bytes30(bytes20(tokensToAdd[i]))))) {
                // token cannot be address(0) or duplicated
                revert TokenAlreadyAdded(tokensToAdd[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _removeTokens(address associated, address[] memory tokensToAdd) private {
        uint256 length = tokensToAdd.length;

        for (uint256 i = 0; i < length;) {
            if (!_tokens.tryRemove(associated, SetValue.wrap(bytes30(bytes20(tokensToAdd[i]))))) {
                // token cannot be address(0) or duplicated
                revert TokenNotExist(tokensToAdd[i]);
            }

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

    function onInstall(bytes calldata data) external override {
        (address[] memory initialTokens) = abi.decode(data, (address[]));

        // require non empty token list
        if (initialTokens.length == 0) {
            revert EmptyTokensNotAllowed();
        }

        address associated = msg.sender; // the associated storage for MSCA (msg.sender)
        _addTokens(associated, initialTokens);
    }

    function onUninstall(bytes calldata) external override {
        _tokens.clear(msg.sender);
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - View functions

    function pluginMetadata() external pure override returns (PluginMetadata memory) {
        PluginMetadata memory metadata;
        metadata.name = _NAME;
        metadata.version = _VERSION;
        metadata.author = _AUTHOR;

        // Permission strings
        string memory modifyTokensListPermission = "Modify tokens list";

        // Permission descriptions
        metadata.permissionDescriptors = new SelectorPermission[](1);
        metadata.permissionDescriptors[0] = SelectorPermission({
            functionSelector: this.updateTokens.selector,
            permissionDescription: modifyTokensListPermission
        });

        return metadata;
    }

    function isAllowedToken(address associated, address tokenToCheck) public view returns (bool) {
        return _tokens.contains(associated, SetValue.wrap(bytes30(bytes20(tokenToCheck))));
    }

    function getTokens(address account) external view returns (address[] memory tokens) {
        SetValue[] memory set = _tokens.getAll(account);
        tokens = new address[](set.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = address(bytes20(bytes32(SetValue.unwrap(set[i]))));
        }

        return tokens;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ITokenWhitelistPlugin).interfaceId || super.supportsInterface(interfaceId);
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                                MANIFEST
    //////////////////////////////////////////////////////////////*/

    // region - Manifest

    function pluginManifest() external pure override returns (PluginManifest memory) {
        PluginManifest memory manifest;

        // dependency
        manifest.dependencyInterfaceIds = new bytes4[](1);
        manifest.dependencyInterfaceIds[0] = type(IMultiOwnerPlugin).interfaceId;

        // runtime execution functions
        manifest.executionFunctions = new bytes4[](3);
        manifest.executionFunctions[0] = this.updateTokens.selector;
        manifest.executionFunctions[1] = this.isAllowedToken.selector;
        manifest.executionFunctions[2] = this.getTokens.selector;

        // runtime validation functions
        ManifestFunction memory runtimeAlwaysAllow = ManifestFunction({
            functionType: ManifestAssociatedFunctionType.RUNTIME_VALIDATION_ALWAYS_ALLOW,
            functionId: 0,
            dependencyIndex: 0
        });

        manifest.runtimeValidationFunctions = new ManifestAssociatedFunction[](3);
        manifest.runtimeValidationFunctions[0] = ManifestAssociatedFunction({
            executionSelector: this.updateTokens.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.DEPENDENCY,
                functionId: 0,
                dependencyIndex: _MANIFEST_DEPENDENCY_INDEX_MULTI_OWNER_USER_OP_VALIDATION
            })
        });
        manifest.runtimeValidationFunctions[1] = ManifestAssociatedFunction({
            executionSelector: this.isAllowedToken.selector,
            associatedFunction: runtimeAlwaysAllow
        });
        manifest.runtimeValidationFunctions[2] = ManifestAssociatedFunction({
            executionSelector: this.getTokens.selector,
            associatedFunction: runtimeAlwaysAllow
        });

        ManifestFunction memory none =
            ManifestFunction({functionType: ManifestAssociatedFunctionType.NONE, functionId: 0, dependencyIndex: 0});

        // pre execution validation
        manifest.executionHooks = new ManifestExecutionHook[](2);
        manifest.executionHooks[0] = ManifestExecutionHook({
            executionSelector: IStandardExecutor.execute.selector,
            preExecHook: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.SELF,
                functionId: uint8(FunctionId.EXECUTE_FUNCTION),
                dependencyIndex: 0
            }),
            postExecHook: none
        });
        manifest.executionHooks[1] = ManifestExecutionHook({
            executionSelector: IStandardExecutor.executeBatch.selector,
            preExecHook: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.SELF,
                functionId: uint8(FunctionId.EXECUTE_BATCH_FUNCTION),
                dependencyIndex: 0
            }),
            postExecHook: none
        });

        return manifest;
    }

    // endregion
}

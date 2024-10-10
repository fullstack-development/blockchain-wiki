// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

import {ITransferLimitPlugin} from "src/interfaces/ITransferLimitPlugin.sol";

contract TransferLimitPlugin is ITransferLimitPlugin, BasePlugin {
    using AssociatedLinkedListSetLib for AssociatedLinkedListSet;

    enum FunctionId {
        EXECUTE_FUNCTION,
        EXECUTE_BATCH_FUNCTION
    }

    struct ERC20SpendLimit {
        address token;
        uint256 limit;
    }

    uint256 internal constant _MANIFEST_DEPENDENCY_INDEX_MULTI_OWNER_USER_OP_VALIDATION = 0;

    string internal constant _NAME = "ERC20 Transfer Limit Plugin";
    string internal constant _VERSION = "1.0.0";
    string internal constant _AUTHOR = "Metalamp";

    AssociatedLinkedListSet private _tokenList;
    mapping(address account => mapping(address token => uint256 limit)) private _limits;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EndBalanceLessThanLimit(address token, uint256 limit);
    error InsufficientBalance(address token, uint256 balance);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LimitUpdated(address indexed token, uint256 limit);

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

            if (_tokenList.contains(msg.sender, SetValue.wrap(bytes30(bytes20(token))))) {
                _checkLimit(token, innerCalldata);
            }
        } else if (functionId == uint8(FunctionId.EXECUTE_BATCH_FUNCTION)) {
            Call[] memory calls = abi.decode(data[4:], (Call[]));

            uint256 length = calls.length;
            for (uint8 i = 0; i < length; i++) {
                if (_tokenList.contains(msg.sender, SetValue.wrap(bytes30(bytes20(calls[i].target))))) {
                    _checkLimit(calls[i].target, calls[i].data);
                }
            }
        }

        return "";
    }

    function _checkLimit(address token, bytes memory innerCalldata) private view {
        bytes4 selector;
        uint256 spend;
        assembly {
            selector := mload(add(innerCalldata, 32)) // 0:32 is arr len, 32:36 is selector
            spend := mload(add(innerCalldata, 68)) // 36:68 is recipient, 68:100 is spend
        }
        if (selector == IERC20.transfer.selector || selector == IERC20.approve.selector) {
            uint256 limit = _limits[msg.sender][token];
            uint256 accountBalance = IERC20(token).balanceOf(msg.sender);

            uint256 endBalance;
            if (accountBalance >= spend) {
                endBalance = accountBalance - spend;
            } else {
                revert InsufficientBalance(token, accountBalance);
            }

            if (endBalance < limit) {
                revert EndBalanceLessThanLimit(token, limit);
            }
        }
    }
    // endregion

    /*//////////////////////////////////////////////////////////////
                          EXECUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - Execution functions

    function updateLimit(address token, uint256 limit) external {
        _tokenList.tryAdd(msg.sender, SetValue.wrap(bytes30(bytes20(token))));
        _limits[msg.sender][token] = limit;

        emit LimitUpdated(token, limit);
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                              INSTALLATION
    //////////////////////////////////////////////////////////////*/

    // region - Installation

    function onInstall(bytes calldata data) external override {
        (ERC20SpendLimit[] memory spendLimits) = abi.decode(data, (ERC20SpendLimit[]));

        uint256 length = spendLimits.length;
        for (uint8 i = 0; i < length; i++) {
            _tokenList.tryAdd(msg.sender, SetValue.wrap(bytes30(bytes20(spendLimits[i].token))));
            _limits[msg.sender][spendLimits[i].token] = spendLimits[i].limit;
        }
    }

    function onUninstall(bytes calldata data) external override {
        (address[] memory tokens) = abi.decode(data, (address[]));

        uint256 length = tokens.length;
        for (uint8 i = 0; i < length; i++) {
            delete _limits[msg.sender][tokens[i]];
        }
        _tokenList.clear(msg.sender);
    }

    // endregion

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // region - View functions

    function getCurrentLimit(address account, address token) external view returns (uint256) {
        return _limits[account][token];
    }

    function getTokensForAccount(address account) external view returns (address[] memory tokens) {
        SetValue[] memory set = _tokenList.getAll(account);
        tokens = new address[](set.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = address(bytes20(bytes32(SetValue.unwrap(set[i]))));
        }
        return tokens;
    }

    function pluginMetadata() external pure override returns (PluginMetadata memory) {
        PluginMetadata memory metadata;
        metadata.name = _NAME;
        metadata.version = _VERSION;
        metadata.author = _AUTHOR;

        // Permission strings
        string memory modifyTokenLimitsPermission = "Modify ERC20 token limits";

        // Permission descriptions
        metadata.permissionDescriptors = new SelectorPermission[](1);
        metadata.permissionDescriptors[0] = SelectorPermission({
            functionSelector: this.updateLimit.selector,
            permissionDescription: modifyTokenLimitsPermission
        });

        return metadata;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ITransferLimitPlugin).interfaceId || super.supportsInterface(interfaceId);
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
        manifest.executionFunctions[0] = this.updateLimit.selector;
        manifest.executionFunctions[1] = this.getTokensForAccount.selector;
        manifest.executionFunctions[2] = this.getCurrentLimit.selector;

        // runtime validation functions
        ManifestFunction memory runtimeAlwaysAllow = ManifestFunction({
            functionType: ManifestAssociatedFunctionType.RUNTIME_VALIDATION_ALWAYS_ALLOW,
            functionId: 0,
            dependencyIndex: 0
        });

        manifest.runtimeValidationFunctions = new ManifestAssociatedFunction[](3);
        manifest.runtimeValidationFunctions[0] = ManifestAssociatedFunction({
            executionSelector: this.updateLimit.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.DEPENDENCY,
                functionId: 0,
                dependencyIndex: _MANIFEST_DEPENDENCY_INDEX_MULTI_OWNER_USER_OP_VALIDATION
            })
        });
        manifest.runtimeValidationFunctions[1] = ManifestAssociatedFunction({
            executionSelector: this.getTokensForAccount.selector,
            associatedFunction: runtimeAlwaysAllow
        });
        manifest.runtimeValidationFunctions[2] = ManifestAssociatedFunction({
            executionSelector: this.getCurrentLimit.selector,
            associatedFunction: runtimeAlwaysAllow
        });

        // pre execution functions
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

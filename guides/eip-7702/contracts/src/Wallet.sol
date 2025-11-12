// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ExecutionHelper} from "@erc7579/core/ExecutionHelper.sol";
import {ExecutionLib} from "@erc7579/lib/ExecutionLib.sol";
import {
    ModeLib,
    ModeCode,
    ModeSelector,
    ModePayload,
    Execution,
    CallType,
    ExecType,
    CALLTYPE_BATCH,
    EXECTYPE_DEFAULT,
    EXECTYPE_TRY,
    CALLTYPE_SINGLE,
    MODE_DEFAULT
} from "@erc7579/lib/ModeLib.sol";
import {ERC1155Holder, IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder, IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import {IWallet} from "./interfaces/IWallet.sol";
import {IERC7821} from "./interfaces/IERC7821.sol";
import {WalletValidator, ExecutionRequest} from "./libraries/WalletValidator.sol";
import {StorageHelper} from "./utils/StorageHelper.sol";

/**
 * @title Wallet
 * @notice A smart contract wallet implementation that supports ERC-7702, ERC-7579 and various other standards
 * @dev Implements IWallet, IERC165, IERC7821, IERC1271, and token receiver interfaces
 */
contract Wallet is IWallet, IERC165, IERC7821, IERC1271, StorageHelper, ExecutionHelper, ERC1155Holder, ERC721Holder {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    /**
     * @notice Ensures the function can only be called by the owner of EOA
     * @dev Used to protect functions that should only be called through execute()
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert OnlySelf();
        }

        _;
    }

    /**
     * @notice Executes a transaction or batch of transactions with the specified mode
     * @param mode The execution mode specifying how the transaction(s) should be handled
     * @param executionCalldata The encoded transaction data to be executed
     */
    function execute(ModeCode mode, bytes calldata executionCalldata)
        external
        payable
        override(IWallet, IERC7821)
        onlySelf
    {
        _execute(mode, executionCalldata);
    }

    /**
     * @notice Executes a transaction after validating the provided signature
     * @param request The execution request containing mode, calldata, salt and deadline
     * @param signature The signature authorizing the execution
     */
    function execute(ExecutionRequest calldata request, bytes calldata signature) external payable {
        Storage storage $ = _getStorage();
        WalletValidator.checkRequest(request, signature, $.isSaltUsed, $.isSaltCancelled);

        $.isSaltUsed[request.salt] = true;
        _execute(request.mode, request.executionCalldata);
    }

    function _execute(ModeCode mode, bytes calldata executionCalldata) private {
        (CallType callType, ExecType execType,,) = mode.decode();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions_ = executionCalldata.decodeBatch();
            if (execType == EXECTYPE_DEFAULT) {
                _execute(executions_);
            } else if (execType == EXECTYPE_TRY) {
                _tryExecute(executions_);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) = executionCalldata.decodeSingle();
            if (execType == EXECTYPE_DEFAULT) {
                _execute(target, value, callData);
            } else if (execType == EXECTYPE_TRY) {
                bytes[] memory returnData_ = new bytes[](1);
                bool success_;
                (success_, returnData_[0]) = _tryExecute(target, value, callData);
                if (!success_) emit TryExecuteUnsuccessful(0, returnData_[0]);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else {
            revert UnsupportedCallType(callType);
        }

        emit Executed(msg.sender, mode, executionCalldata);
    }

    /**
     * @notice Cancels a signature by marking its salt as cancelled
     * @param salt The salt of the signature to cancel
     */
    function cancelSignature(bytes32 salt) external onlySelf {
        Storage storage $ = _getStorage();
        if ($.isSaltCancelled[salt]) {
            revert SignatureAlreadyCancelled();
        }

        $.isSaltCancelled[salt] = true;

        emit SignatureCancelled(salt);
    }

    /**
     * @notice Checks if a specific salt has been used
     * @param salt The salt to check
     * @return bool True if the salt has been used, false otherwise
     */
    function isSaltUsed(bytes32 salt) external view returns (bool) {
        return _getStorage().isSaltUsed[salt];
    }

    /**
     * @notice Checks if a specific salt has been cancelled
     * @param salt The salt to check
     * @return bool True if the salt has been cancelled, false otherwise
     */
    function isSaltCancelled(bytes32 salt) external view returns (bool) {
        return _getStorage().isSaltCancelled[salt];
    }

    /// @notice Implementation of ERC1271
    /// @dev Should return whether the signature provided is valid for the provided data
    /// @param hash Hash of the data to be signed
    /// @param signature Signature byte array associated with hash
    /// @return magicValue The bytes4 magic value 0x1626ba7e if valid
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        override(IWallet, IERC1271)
        returns (bytes4 magicValue)
    {
        bool isValid = WalletValidator.isValidERC1271Signature(hash, signature);
        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }
        return 0xffffffff;
    }

    /// @notice Supports the following interfaces: IWallet, IERC721Receiver, IERC1155Receiver, IERC165, IERC1271
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC1155Holder) returns (bool) {
        return interfaceId == type(IWallet).interfaceId || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC1271).interfaceId || interfaceId == type(IERC7821).interfaceId;
    }

    /**
     * @notice Returns a boolean indicating if a mode is supported
     * @param mode The mode to validate
     * @return True if the mode is supported, else - false
     */
    function supportsExecutionMode(ModeCode mode) external view virtual override returns (bool) {
        (CallType callType, ExecType execType, ModeSelector modeSelector, ModePayload modePayload) = mode.decode();

        return (
            (callType == CALLTYPE_SINGLE || callType == CALLTYPE_BATCH)
                && (execType == EXECTYPE_DEFAULT || execType == EXECTYPE_TRY) && (modeSelector == MODE_DEFAULT)
                && (ModePayload.unwrap(modePayload) == bytes22(0x00))
        );
    }

    /// @notice Allows this contract to receive the chains native token
    receive() external payable {}
}

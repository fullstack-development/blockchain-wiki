// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, StdCheats} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ModeLib,
    ModeCode,
    ModeSelector,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    EXECTYPE_DEFAULT,
    EXECTYPE_TRY,
    MODE_DEFAULT,
    ModePayload,
    CallType,
    ExecType
} from "@erc7579/lib/ModeLib.sol";
import {ExecutionLib, Execution} from "@erc7579/lib/ExecutionLib.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import {Wallet, IWallet} from "src/wallet/Wallet.sol";
import {IERC7821} from "src/wallet/interfaces/IERC7821.sol";
import {WalletValidator, ExecutionRequest} from "src/wallet/libraries/WalletValidator.sol";

import {ERC721Mock} from "../mocks/ERC721Mock.sol";
import {ERC1155Mock} from "../mocks/ERC1155Mock.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {SigUtils} from "./utils/SigUtils.sol";

contract WalletTest is Test {
    Wallet public wallet;
    ERC721Mock public erc721Token;
    ERC1155Mock public erc1155Token;
    ERC20Mock public erc20Token;
    SigUtils public sigUtils;

    StdCheats.Account user;

    function setUp() external {
        user = makeAccount("user");

        wallet = new Wallet();
        erc721Token = new ERC721Mock();
        erc1155Token = new ERC1155Mock();
        erc20Token = new ERC20Mock("Tether USD", "USDT", 6);
        sigUtils = new SigUtils(user.addr);

        vm.startBroadcast(user.key);

        vm.signAndAttachDelegation(address(wallet), user.key);
        assertTrue(address(user.addr).code.length > 0);

        vm.stopBroadcast();

        vm.label(address(wallet), "Wallet");
        vm.label(user.addr, "User");
        vm.label(address(erc20Token), "USDT");
    }

    // region - User transfer native currency-

    function test_execute_transferNative(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(recipient, amount, "");

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(recipient.balance, amount);
        assertEq(user.addr.balance, 0);
    }

    function test_execute_transferNative_revertIfNotSelf(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(recipient, amount, "");

        vm.expectRevert(IWallet.OnlySelf.selector);

        IWallet(user.addr).execute(modeCode, userOpCalldata);
    }

    // endregion

    // region - User transfer erc-20 token -

    function test_execute_transferERC20(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_transferERC20_revertIfNotSelf(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();

        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.expectRevert(IWallet.OnlySelf.selector);

        IWallet(user.addr).execute(modeCode, userOpCalldata);
    }

    // endregion

    // region - Single execute -

    function test_execute_revertIfUnsupportedCallType(uint256 amount, bytes1 invalidCallType) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        vm.assume(
            invalidCallType != 0x00 && invalidCallType != 0x01 && invalidCallType != 0xFE && invalidCallType != 0xFF
        );

        ModeCode modeCode =
            ModeLib.encode(CallType.wrap(invalidCallType), EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.expectRevert(abi.encodeWithSelector(IWallet.UnsupportedCallType.selector, invalidCallType));

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);
    }

    function test_execute_CALLTYPE_SINGLE_EXECTYPE_DEFAULT(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_CALLTYPE_SINGLE_EXECTYPE_TRY(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_CALLTYPE_SINGLE_EXECTYPE_TRY_emitTryExecuteUnsuccessful(uint256 amount) external {
        address recipient = makeAddr("recipient");

        ModeCode modeCode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        // TODO: We can't check event, because it has place in deep callstack. Revert is happen earlier
        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(recipient), 0);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_CALLTYPE_SINGLE_revertIfUnsupportedExecType(uint256 amount, bytes1 invalidExecType)
        external
    {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        vm.assume(invalidExecType != 0x00 && invalidExecType != 0x01);

        ModeCode modeCode =
            ModeLib.encode(CALLTYPE_SINGLE, ExecType.wrap(invalidExecType), MODE_DEFAULT, ModePayload.wrap(0x00));
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        vm.expectRevert(abi.encodeWithSelector(IWallet.UnsupportedExecType.selector, invalidExecType));

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);
    }

    // endregion

    // region - Batch execute -

    function test_execute_CALLTYPE_BATCH_EXECTYPE_DEFAULT(uint64 amount) external {
        SpenderMock spender = new SpenderMock();
        vm.label(address(spender), "Spender");

        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(erc20Token),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(spender), amount)
        });
        executions[1] = Execution({
            target: address(spender),
            value: 0,
            callData: abi.encodeWithSelector(SpenderMock.deposit.selector, address(erc20Token), amount)
        });

        bytes memory userOpCalldata = ExecutionLib.encodeBatch(executions);

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(address(spender)), amount);
        assertEq(erc20Token.allowance(user.addr, address(spender)), 0);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_CALLTYPE_BATCH_EXECTYPE_TRY(uint64 amount) external {
        SpenderMock spender = new SpenderMock();
        vm.label(address(spender), "Spender");

        ModeCode modeCode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(erc20Token),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(spender), amount)
        });
        executions[1] = Execution({
            target: address(spender),
            value: 0,
            callData: abi.encodeWithSelector(SpenderMock.deposit.selector, address(erc20Token), amount)
        });

        bytes memory userOpCalldata = ExecutionLib.encodeBatch(executions);

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);

        assertEq(erc20Token.balanceOf(address(spender)), 0);
        assertEq(erc20Token.allowance(user.addr, address(spender)), amount);
        assertEq(erc20Token.balanceOf(user.addr), 0);
    }

    function test_execute_CALLTYPE_BATCH_revertIfUnsupportedExecType(uint64 amount, bytes1 invalidExecType) external {
        SpenderMock spender = new SpenderMock();
        vm.label(address(spender), "Spender");

        deal(address(erc20Token), user.addr, amount);

        vm.assume(invalidExecType != 0x00 && invalidExecType != 0x01);

        ModeCode modeCode =
            ModeLib.encode(CALLTYPE_BATCH, ExecType.wrap(invalidExecType), MODE_DEFAULT, ModePayload.wrap(0x00));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(erc20Token),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(spender), amount)
        });
        executions[1] = Execution({
            target: address(spender),
            value: 0,
            callData: abi.encodeWithSelector(SpenderMock.deposit.selector, address(erc20Token), amount)
        });

        bytes memory userOpCalldata = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(abi.encodeWithSelector(IWallet.UnsupportedExecType.selector, invalidExecType));

        vm.prank(user.addr);
        IWallet(user.addr).execute(modeCode, userOpCalldata);
    }

    // endregion

    // region - Execute with signature -

    function _beforeEach_executeWithSignature(ModeCode modeCode, bytes memory userOpCalldata)
        private
        returns (address sender, ExecutionRequest memory request, bytes memory signature)
    {
        sender = makeAddr("sender");
        vm.label(sender, "Sender");

        request = ExecutionRequest({
            mode: modeCode,
            executionCalldata: userOpCalldata,
            salt: keccak256(abi.encodePacked(vm.randomUint())),
            deadline: uint64(block.timestamp)
        });

        signature = _signWalletOperation(request, sender, user.key);
    }

    function test_executeWithSignature(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender, ExecutionRequest memory request, bytes memory signature) =
            _beforeEach_executeWithSignature(modeCode, userOpCalldata);

        vm.prank(sender);
        IWallet(user.addr).execute(request, signature);

        assertEq(erc20Token.balanceOf(recipient), amount);
        assertEq(erc20Token.balanceOf(user.addr), 0);
        assertTrue(IWallet(user.addr).isSaltUsed(request.salt));
        assertFalse(wallet.isSaltUsed(request.salt));
    }

    function test_executeWithSignature_revertIfRequestExpired(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender, ExecutionRequest memory request, bytes memory signature) =
            _beforeEach_executeWithSignature(modeCode, userOpCalldata);

        vm.warp(block.timestamp + 1);

        vm.expectRevert(WalletValidator.RequestExpired.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(request, signature);
    }

    function test_executeWithSignature_revertIfSaltAlreadyUsed(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender, ExecutionRequest memory request, bytes memory signature) =
            _beforeEach_executeWithSignature(modeCode, userOpCalldata);

        vm.prank(sender);
        IWallet(user.addr).execute(request, signature);

        vm.expectRevert(WalletValidator.SaltAlreadyUsed.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(request, signature);
    }

    function test_executeWithSignature_revertIfSaltCancelled(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender, ExecutionRequest memory request, bytes memory signature) =
            _beforeEach_executeWithSignature(modeCode, userOpCalldata);

        vm.prank(user.addr);
        IWallet(user.addr).cancelSignature(request.salt);

        vm.expectRevert(WalletValidator.SaltCancelled.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(request, signature);
    }

    function test_executeWithSignature_revertIfInvalidSignature_invalidSender(uint256 amount) external {
        address recipient = makeAddr("recipient");
        address invalidSender = makeAddr("invalidSender");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (, ExecutionRequest memory request, bytes memory signature) =
            _beforeEach_executeWithSignature(modeCode, userOpCalldata);

        vm.expectRevert(WalletValidator.InvalidSignature.selector);

        vm.prank(invalidSender);
        IWallet(user.addr).execute(request, signature);
    }

    function test_executeWithSignature_revertIfInvalidSignature_invalidModeRequest(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender,, bytes memory signature) = _beforeEach_executeWithSignature(modeCode, userOpCalldata);
        ExecutionRequest memory invalidModeRequest = ExecutionRequest({
            mode: ModeLib.encodeSimpleBatch(),
            executionCalldata: userOpCalldata,
            salt: keccak256(abi.encodePacked(vm.randomUint())),
            deadline: uint64(block.timestamp)
        });

        vm.expectRevert(WalletValidator.InvalidSignature.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(invalidModeRequest, signature);
    }

    function test_executeWithSignature_revertIfInvalidSignature_invalidExecutionCalldataRequest(uint256 amount)
        external
    {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender,, bytes memory signature) = _beforeEach_executeWithSignature(modeCode, userOpCalldata);
        ExecutionRequest memory invalidModeRequest = ExecutionRequest({
            mode: modeCode,
            executionCalldata: ExecutionLib.encodeSingle(
                address(0), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
            ),
            salt: keccak256(abi.encodePacked(vm.randomUint())),
            deadline: uint64(block.timestamp)
        });

        vm.expectRevert(WalletValidator.InvalidSignature.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(invalidModeRequest, signature);
    }

    function test_executeWithSignature_revertIfInvalidSignature_invalidSaltRequest(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender,, bytes memory signature) = _beforeEach_executeWithSignature(modeCode, userOpCalldata);
        bytes32 invalidSalt = keccak256(abi.encodePacked(vm.randomUint()));
        ExecutionRequest memory invalidModeRequest = ExecutionRequest({
            mode: modeCode,
            executionCalldata: userOpCalldata,
            salt: invalidSalt,
            deadline: uint64(block.timestamp)
        });

        vm.expectRevert(WalletValidator.InvalidSignature.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(invalidModeRequest, signature);
    }

    function test_executeWithSignature_revertIfInvalidSignature_invalidDeadlineRequest(uint256 amount) external {
        address recipient = makeAddr("recipient");
        deal(address(erc20Token), user.addr, amount);

        ModeCode modeCode = ModeLib.encodeSimpleSingle();
        bytes memory userOpCalldata = ExecutionLib.encodeSingle(
            address(erc20Token), 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        (address sender,, bytes memory signature) = _beforeEach_executeWithSignature(modeCode, userOpCalldata);
        uint64 invalidDeadline = uint64(block.timestamp + vm.randomUint(0, type(uint32).max));
        ExecutionRequest memory invalidModeRequest = ExecutionRequest({
            mode: modeCode,
            executionCalldata: userOpCalldata,
            salt: keccak256(abi.encodePacked(vm.randomUint())),
            deadline: invalidDeadline
        });

        vm.expectRevert(WalletValidator.InvalidSignature.selector);

        vm.prank(sender);
        IWallet(user.addr).execute(invalidModeRequest, signature);
    }

    // endregion

    // region - Wallet can get other tokens -

    function test_sendERC721() external {
        address sender = makeAddr("sender");
        uint256 tokenId = 1;

        erc721Token.mint(sender, tokenId);

        vm.prank(sender);
        erc721Token.safeTransferFrom(sender, address(wallet), tokenId);

        assertEq(erc721Token.ownerOf(tokenId), address(wallet));
        assertNotEq(erc721Token.ownerOf(tokenId), sender);
    }

    function test_sendERC1155() external {
        address sender = makeAddr("sender");
        uint256 tokenId = 1;
        uint256 value = 1;

        erc1155Token.mint(sender, tokenId, value);

        vm.prank(sender);
        erc1155Token.safeTransferFrom(sender, address(wallet), tokenId, value, "");

        assertEq(erc1155Token.balanceOf(address(wallet), tokenId), value);
        assertEq(erc1155Token.balanceOf(sender, tokenId), 0);
    }

    function test_sendNative(uint256 value) external {
        address sender = makeAddr("sender");
        deal(sender, value);

        vm.prank(sender);
        (bool success,) = address(wallet).call{value: value}("");

        assertTrue(success);
        assertEq(address(wallet).balance, value);
        assertEq(sender.balance, 0);
    }

    // endregion

    // region - Cancel signature -

    function test_cancelSignature() external {
        bytes32 salt = keccak256(abi.encodePacked(vm.randomUint()));

        vm.prank(user.addr);
        IWallet(user.addr).cancelSignature(salt);

        assertTrue(IWallet(user.addr).isSaltCancelled(salt));
    }

    function test_cancelSignature_revertIfNotSelf() external {
        bytes32 salt = keccak256(abi.encodePacked(vm.randomUint()));

        vm.expectRevert(IWallet.OnlySelf.selector);

        IWallet(user.addr).cancelSignature(salt);
    }

    function test_cancelSignature_revertIfSignatureAlreadyCancelled() external {
        bytes32 salt = keccak256(abi.encodePacked(vm.randomUint()));

        vm.prank(user.addr);
        IWallet(user.addr).cancelSignature(salt);

        vm.expectRevert(IWallet.SignatureAlreadyCancelled.selector);

        vm.prank(user.addr);
        IWallet(user.addr).cancelSignature(salt);
    }

    // endregion

    // region - Supports Interface -

    function test_supportsInterface_IWallet() external view {
        bytes4 interfaceId = type(IWallet).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IWallet should be supported");
    }

    function test_supportsInterface_IERC721Receiver() external view {
        bytes4 interfaceId = type(IERC721Receiver).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IERC721Receiver should be supported");
    }

    function test_supportsInterface_IERC1155Receiver() external view {
        bytes4 interfaceId = type(IERC1155Receiver).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IERC1155Receiver should be supported");
    }

    function test_supportsInterface_IERC165() external view {
        bytes4 interfaceId = type(IERC165).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IERC165 should be supported");
    }

    function test_supportsInterface_IERC1271() external view {
        bytes4 interfaceId = type(IERC1271).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IERC1271 should be supported");
    }

    function test_supportsInterface_IERC7821() external view {
        bytes4 interfaceId = type(IERC7821).interfaceId;
        assertTrue(wallet.supportsInterface(interfaceId), "IERC7821 should be supported");
    }

    function test_supportsInterface_unsupportedInterface() external view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(wallet.supportsInterface(unsupportedInterfaceId), "Unsupported interface should return false");
    }

    // endregion

    // region - Supports Execution Mode -

    function test_supportsExecutionMode_validModes() external view {
        ModeCode validModeSingleDefault = ModeLib.encodeSimpleSingle();
        ModeCode validModeBatchDefault =
            ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));
        ModeCode validModeSingleTry =
            ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        ModeCode validModeBatchTry = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        assertTrue(wallet.supportsExecutionMode(validModeSingleDefault), "Single Default mode should be supported");
        assertTrue(wallet.supportsExecutionMode(validModeBatchDefault), "Batch Default mode should be supported");
        assertTrue(wallet.supportsExecutionMode(validModeSingleTry), "Single Try mode should be supported");
        assertTrue(wallet.supportsExecutionMode(validModeBatchTry), "Batch Try mode should be supported");
    }

    function test_supportsExecutionMode_invalidCallType() external view {
        ModeCode invalidCallTypeMode =
            ModeLib.encode(CallType.wrap(0x02), EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));
        assertFalse(wallet.supportsExecutionMode(invalidCallTypeMode), "Invalid CallType should not be supported");
    }

    function test_supportsExecutionMode_invalidExecType() external view {
        ModeCode invalidExecTypeMode =
            ModeLib.encode(CALLTYPE_SINGLE, ExecType.wrap(0x02), MODE_DEFAULT, ModePayload.wrap(0x00));
        assertFalse(wallet.supportsExecutionMode(invalidExecTypeMode), "Invalid ExecType should not be supported");
    }

    function test_supportsExecutionMode_invalidModeSelector() external view {
        ModeCode invalidModeSelectorMode =
            ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, ModeSelector.wrap("0x01"), ModePayload.wrap(0x00));
        assertFalse(
            wallet.supportsExecutionMode(invalidModeSelectorMode), "Invalid ModeSelector should not be supported"
        );
    }

    function test_supportsExecutionMode_invalidModePayload() external view {
        ModeCode invalidModePayloadMode =
            ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap("0x01"));
        assertFalse(wallet.supportsExecutionMode(invalidModePayloadMode), "Invalid ModePayload should not be supported");
    }

    // endregion

    // region - ERC1271 -

    function test_isValidSignature() external {
        bytes32 hash = keccak256("test message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user.addr);
        bytes4 magicValue = IWallet(user.addr).isValidSignature(hash, signature);

        assertEq(magicValue, IERC1271.isValidSignature.selector);
    }

    function test_isValidSignature_invalidSignature() external {
        bytes32 hash = keccak256("test message");
        uint256 invalidKey = 0x12345;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(invalidKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user.addr);
        bytes4 magicValue = wallet.isValidSignature(hash, signature);

        assertEq(magicValue, bytes4(0xffffffff));
    }

    // endregion

    // region - Service functions -

    function _signWalletOperation(ExecutionRequest memory request, address sender, uint256 privateKey)
        private
        view
        returns (bytes memory signature)
    {
        bytes32 digest = sigUtils.getDigest(request, sender);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        signature = abi.encodePacked(r, s, v);
    }

    // endregion
}

contract SpenderMock {
    function deposit(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}

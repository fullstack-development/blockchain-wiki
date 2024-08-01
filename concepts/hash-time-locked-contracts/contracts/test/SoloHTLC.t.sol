// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console, StdCheats} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SoloHTLC as HTLC, LockOrder, MIN_LOCK_TIME, NATIVE_CURRENCY} from "../src/SoloHTLC/SoloHTLC.sol";
import {FactorySoloHTLC} from "../src/SoloHTLC/FactorySoloHTLC.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

uint256 constant INITIAL_VALUE = 1e18;

contract SoloHTLCTest is Test {
    address sender;
    address recipient;

    bytes secret = "test secret phrase";
    bytes32 secretHash = keccak256(abi.encodePacked(secret));

    FactorySoloHTLC factory;
    ERC20Mock PEPE;

    event Locked(LockOrder lockOrder);
    event Claimed(bytes secret, LockOrder lockOrder);
    event Refunded(LockOrder lockOrder);

    function setUp() public {
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        PEPE = new ERC20Mock(18);
        factory = new FactorySoloHTLC();
    }

    // region - Deploy -

    function _beforeEach_deploy(address token) private view returns (LockOrder memory lockOrder) {
        lockOrder = LockOrder({
            sender: sender,
            recipient: recipient,
            secretHash: secretHash,
            token: token,
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });
    }

    function test_deploy_withNativeCurrency() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        vm.prank(sender);
        HTLC htlc = HTLC(factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint()));

        assertEq(htlc.getLockOrder().sender, sender);
        assertEq(htlc.getLockOrder().recipient, recipient);
        assertEq(htlc.getLockOrder().secretHash, secretHash);
        assertEq(htlc.getLockOrder().token, token);
        assertEq(htlc.getLockOrder().value, INITIAL_VALUE);
        assertGt(htlc.getLockOrder().expiredTime, 0);

        assertEq(address(htlc).balance, INITIAL_VALUE);
    }

    function test_deploy_withNativeCurrency_emitLocked() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        vm.expectEmit(true, true, true, true);
        emit Locked(lockOrder);

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_withERC20() external {
        address token = address(PEPE);
        uint256 salt = vm.randomUint();
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        StdCheats.deal(address(PEPE), sender, INITIAL_VALUE);

        bytes memory bytecode = abi.encodePacked(type(HTLC).creationCode, abi.encode(lockOrder));
        address htlcAddress = factory.getHTLCAddress(bytecode, salt);

        vm.startPrank(sender);

        IERC20(lockOrder.token).approve(htlcAddress, lockOrder.value);

        HTLC htlc = HTLC(factory.createHTLC(lockOrder, salt));

        vm.stopPrank();

        assertEq(htlc.getLockOrder().sender, sender);
        assertEq(htlc.getLockOrder().recipient, recipient);
        assertEq(htlc.getLockOrder().secretHash, secretHash);
        assertEq(htlc.getLockOrder().token, token);
        assertEq(htlc.getLockOrder().value, INITIAL_VALUE);
        assertGt(htlc.getLockOrder().expiredTime, 0);

        assertEq(IERC20(lockOrder.token).balanceOf(htlcAddress), INITIAL_VALUE);
    }

    function test_deploy_withERC20_emitLocked() external {
        address token = address(PEPE);
        uint256 salt = vm.randomUint();
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        StdCheats.deal(address(PEPE), sender, INITIAL_VALUE);

        bytes memory bytecode = abi.encodePacked(type(HTLC).creationCode, abi.encode(lockOrder));
        address htlcAddress = factory.getHTLCAddress(bytecode, salt);

        vm.startPrank(sender);

        IERC20(lockOrder.token).approve(htlcAddress, lockOrder.value);

        vm.expectEmit(true, true, true, true);
        emit Locked(lockOrder);

        factory.createHTLC(lockOrder, salt);

        vm.stopPrank();
    }

    function test_deploy_revertIfInvalidSender() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        lockOrder.sender = address(0);

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_revertIfInvalidRecipient() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        lockOrder.recipient = address(0);

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_revertIfInvalidSecretHash() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        lockOrder.secretHash = bytes32(0);

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_revertIfInvalidValue() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        lockOrder.value = 0;

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_revertIfInvalidExpiredTime() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);
        vm.deal(sender, INITIAL_VALUE);

        lockOrder.expiredTime = uint64(block.timestamp);

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: lockOrder.value}(lockOrder, vm.randomUint());
    }

    function test_deploy_revertIfInsufficientAmount() external {
        address token = address(0);
        LockOrder memory lockOrder = _beforeEach_deploy(token);

        vm.expectRevert();

        vm.prank(sender);
        factory.createHTLC{value: 0}(lockOrder, vm.randomUint());
    }

    // endregion

    // region - Claim -

    function _beforeEach_claim() private returns (address htlcWithNative, address htlcWithERC20, LockOrder memory lockOrderNative, LockOrder memory lockOrderERC20) {
        // Create htlc with native currency
        vm.deal(sender, INITIAL_VALUE);
        lockOrderNative = LockOrder({
            sender: sender,
            recipient: recipient,
            secretHash: secretHash,
            token: NATIVE_CURRENCY,
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });
        vm.prank(sender);
        htlcWithNative = factory.createHTLC{value: INITIAL_VALUE}(
            lockOrderNative,
            vm.randomUint()
        );

        // Create htlc with ERC-20
        uint256 salt = vm.randomUint();
        lockOrderERC20 = LockOrder({
            sender: sender,
            recipient: recipient,
            secretHash: secretHash,
            token: address(PEPE),
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });
        StdCheats.deal(address(PEPE), sender, INITIAL_VALUE);

        bytes memory bytecode = abi.encodePacked(type(HTLC).creationCode, abi.encode(lockOrderERC20));

        address htlcAddress = factory.getHTLCAddress(bytecode, salt);

        vm.startPrank(sender);

        IERC20(lockOrderERC20.token).approve(htlcAddress, lockOrderERC20.value);

        htlcWithERC20 = factory.createHTLC(lockOrderERC20, salt);

        vm.stopPrank();

        assertNotEq(htlcWithNative, address(0));
        assertNotEq(htlcWithERC20, address(0));
    }

    function test_claim() external {
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_claim();

        vm.prank(recipient);
        HTLC(htlcWithNative).claim(secret);

        assertEq(recipient.balance, INITIAL_VALUE);
        assertEq(htlcWithNative.balance, 0);

        vm.prank(recipient);
        HTLC(htlcWithERC20).claim(secret);

        assertEq(IERC20(PEPE).balanceOf(recipient), INITIAL_VALUE);
        assertEq(IERC20(PEPE).balanceOf(htlcWithERC20), 0);
    }

    function test_claim_emitClaimed() external {
        (address htlcWithNative, address htlcWithERC20, LockOrder memory lockOrderNative, LockOrder memory lockOrderERC20) = _beforeEach_claim();

        vm.expectEmit(true, true, true, true);
        emit Claimed(secret, lockOrderNative);

        vm.prank(recipient);
        HTLC(htlcWithNative).claim(secret);

        vm.expectEmit(true, true, true, true);
        emit Claimed(secret, lockOrderERC20);

        vm.prank(recipient);
        HTLC(htlcWithERC20).claim(secret);
    }

    function test_claim_revertIfInvalidSecret() external {
        bytes memory invalidSecret = "invalid secret";

        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_claim();

        vm.expectRevert(HTLC.InvalidSecret.selector);
        vm.prank(recipient);
        HTLC(htlcWithNative).claim(invalidSecret);

        vm.expectRevert(HTLC.InvalidSecret.selector);
        vm.prank(recipient);
        HTLC(htlcWithERC20).claim(invalidSecret);
    }

    function test_claim_revertIfInvalidRecipient() external {
        address invalidRecipient = makeAddr("invalidRecipient");
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_claim();

        vm.expectRevert(HTLC.InvalidRecipient.selector);
        vm.prank(invalidRecipient);
        HTLC(htlcWithNative).claim(secret);

        vm.expectRevert(HTLC.InvalidRecipient.selector);
        vm.prank(invalidRecipient);
        HTLC(htlcWithERC20).claim(secret);
    }

    function test_claim_revertIfClaimHasExpired() external {
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_claim();

        vm.warp(block.timestamp + MIN_LOCK_TIME);

        vm.expectRevert(HTLC.ClaimHasExpired.selector);
        vm.prank(recipient);
        HTLC(htlcWithNative).claim(secret);

        vm.expectRevert(HTLC.ClaimHasExpired.selector);
        vm.prank(recipient);
        HTLC(htlcWithERC20).claim(secret);
    }

    // endregion

    // region - Refund -

    function _beforeEach_refund() private returns (address htlcWithNative, address htlcWithERC20, LockOrder memory lockOrderNative, LockOrder memory lockOrderERC20) {
        // Create htlc with native currency
        vm.deal(sender, INITIAL_VALUE);
        lockOrderNative = LockOrder({
            sender: sender,
            recipient: recipient,
            secretHash: secretHash,
            token: NATIVE_CURRENCY,
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });
        vm.prank(sender);
        htlcWithNative = factory.createHTLC{value: INITIAL_VALUE}(
            lockOrderNative,
            vm.randomUint()
        );

        // Create htlc with ERC-20
        uint256 salt = vm.randomUint();
        lockOrderERC20 = LockOrder({
            sender: sender,
            recipient: recipient,
            secretHash: secretHash,
            token: address(PEPE),
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });
        StdCheats.deal(address(PEPE), sender, INITIAL_VALUE);

        bytes memory bytecode = abi.encodePacked(type(HTLC).creationCode, abi.encode(lockOrderERC20));

        address htlcAddress = factory.getHTLCAddress(bytecode, salt);

        vm.startPrank(sender);

        IERC20(lockOrderERC20.token).approve(htlcAddress, lockOrderERC20.value);

        htlcWithERC20 = factory.createHTLC(lockOrderERC20, salt);

        vm.stopPrank();

        assertNotEq(htlcWithNative, address(0));
        assertNotEq(htlcWithERC20, address(0));

        // move timestamp
        vm.warp(block.timestamp + MIN_LOCK_TIME + 1);
    }

    function test_refund() external {
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_refund();

        vm.prank(sender);
        HTLC(htlcWithNative).refund();

        assertEq(sender.balance, INITIAL_VALUE);
        assertEq(htlcWithNative.balance, 0);

        vm.prank(sender);
        HTLC(htlcWithERC20).refund();

        assertEq(IERC20(PEPE).balanceOf(sender), INITIAL_VALUE);
        assertEq(IERC20(PEPE).balanceOf(htlcWithNative), 0);
    }

    function test_refund_emitRefunded() external {
        (address htlcWithNative, address htlcWithERC20, LockOrder memory lockOrderNative, LockOrder memory lockOrderERC20) = _beforeEach_refund();

        vm.expectEmit(true, true, true, true);
        emit Refunded(lockOrderNative);

        vm.prank(sender);
        HTLC(htlcWithNative).refund();

        vm.expectEmit(true, true, true, true);
        emit Refunded(lockOrderERC20);

        vm.prank(sender);
        HTLC(htlcWithERC20).refund();
    }

    function test_refund_revertIfInvalidSender() external {
        address invalidSender = makeAddr("invalidSender");
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_refund();

        vm.expectRevert(HTLC.InvalidSender.selector);

        vm.prank(invalidSender);
        HTLC(htlcWithNative).refund();

        vm.expectRevert(HTLC.InvalidSender.selector);

        vm.prank(invalidSender);
        HTLC(htlcWithERC20).refund();
    }

    function test_refund_revertIfRefundHasNotExpiredYet() external {
        (address htlcWithNative, address htlcWithERC20,,) = _beforeEach_refund();

        vm.warp(block.timestamp - MIN_LOCK_TIME);

        vm.expectRevert(HTLC.RefundHasNotExpiredYet.selector);

        vm.prank(sender);
        HTLC(htlcWithNative).refund();

        vm.expectRevert(HTLC.RefundHasNotExpiredYet.selector);

        vm.prank(sender);
        HTLC(htlcWithERC20).refund();
    }

    function test_refund_revertIfTransferFailed() external {
        Sender senderIsContract = new Sender();

        vm.deal(address(senderIsContract), INITIAL_VALUE);
        LockOrder memory lockOrder = LockOrder({
            sender: address(senderIsContract),
            recipient: recipient,
            secretHash: secretHash,
            token: NATIVE_CURRENCY,
            value: INITIAL_VALUE,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        address htlcAddress = senderIsContract.lock(factory, lockOrder);

        // move timestamp
        vm.warp(block.timestamp + MIN_LOCK_TIME + 1);

        vm.expectRevert(HTLC.TransferFailed.selector);

        senderIsContract.refund(HTLC(htlcAddress));
    }

    // endregion
}

contract Sender is Test {
    function lock(FactorySoloHTLC factory, LockOrder memory lockOrder) external returns (address htlcAddress) {
        htlcAddress = factory.createHTLC{value: INITIAL_VALUE}(
            lockOrder,
            vm.randomUint()
        );
    }

    function refund(HTLC htlc) external {
        htlc.refund();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console, StdCheats} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SingleHTLC as HTLC, Order, MIN_LOCK_TIME, NATIVE_CURRENCY, MIN_DIFFERENCE_BETWEEN_ORDERS} from "../src/SingleHTLC.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

uint256 constant INITIAL_VALUE = 1e18;

contract SingleHTLCTest is Test {
    address userA;
    address userB;

    bytes secret = "test secret phrase";
    bytes32 secretHash = keccak256(abi.encodePacked(secret));

    ERC20Mock PEPE;
    HTLC htlc;

    event Locked(Order order, bytes32 indexed secretHash, address indexed sender);
    event Redeemed(bytes secret, bytes32 secretHash, address indexed token, address indexed sender, uint256 value);
    event Claimed(bytes secret, bytes32 secretHash, address indexed token, address indexed sender, uint256 value);
    event Refunded(bytes32 secretHash, address indexed token, address indexed sender, uint256 value);

    function setUp() public {
        userA = makeAddr("userA");
        userB = makeAddr("userB");

        PEPE = new ERC20Mock(18);
        htlc = new HTLC();
    }

    function test_deploy() external view {
        assertNotEq(address(htlc), address(0));
    }

    // region - Lock order -

    function _beforeEach_lock(address token) private returns (Order memory order) {
        order = Order({
            recipient: userB,
            value: INITIAL_VALUE,
            token: token,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        token == NATIVE_CURRENCY
            ? deal(userA, INITIAL_VALUE)
            : StdCheats.deal(address(token), userA, INITIAL_VALUE);
    }

    function test_lock_withNative() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);

        assertEq(userA.balance, 0);
        assertEq(address(htlc).balance, order.value);
    }

    function test_lock_withNative_emitLocked() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);

        vm.expectEmit(true, true, true, true);
        emit Locked(order, secretHash, userA);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);
    }

    function test_lock_withERC20() external {
        address token = address(PEPE);
        Order memory order = _beforeEach_lock(token);

        vm.startPrank(userA);

        IERC20(token).approve(address(htlc), order.value);

        htlc.lock(order, secretHash);

        vm.stopPrank();

        assertEq(IERC20(token).balanceOf(userA), 0);
        assertEq(IERC20(token).balanceOf(address(htlc)), order.value);
    }

    function test_lock_revertIfOrderHasLocked() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);

        deal(userA, INITIAL_VALUE);

        vm.expectRevert(HTLC.OrderHasLocked.selector);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);
    }

    function test_lock_revertIfExpiredTimeShouldLessThanRecipientOrder() external {
        address token = NATIVE_CURRENCY;
        Order memory orderA = _beforeEach_lock(token);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        Order memory orderB = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: token,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userB, INITIAL_VALUE);

        vm.expectRevert(HTLC.ExpiredTimeShouldLessThanRecipientOrder.selector);

        vm.prank(userB);
        htlc.lock{value: orderB.value}(orderB, secretHash);
    }

    function test_lock_revertIfInvalidRecipient() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);
        order.recipient = address(0);

        vm.expectRevert(HTLC.InvalidRecipient.selector);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);
    }

    function test_lock_revertIfInvalidValue() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);
        order.value = 0;

        vm.expectRevert(HTLC.InvalidValue.selector);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);
    }

    function test_lock_revertIfInvalidExpiredTime() external {
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);
        order.expiredTime = uint64(block.timestamp);

        vm.expectRevert(HTLC.InvalidExpiredTime.selector);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, secretHash);
    }

    function test_lock_revertIfInvalidSecretHash() external {
        bytes32 invalidSecretHash = bytes32(0);
        address token = NATIVE_CURRENCY;
        Order memory order = _beforeEach_lock(token);

        vm.expectRevert(HTLC.InvalidSecretHash.selector);

        vm.prank(userA);
        htlc.lock{value: order.value}(order, invalidSecretHash);
    }

    // endregion

    // region - Redeem -

    function _beforeEach_redeem() private {
        // UserA changes ETH for PEPE of the userB
        Order memory orderA = Order({
            recipient: userB,
            value: INITIAL_VALUE,
            token: NATIVE_CURRENCY,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        // UserB will fulfill userA's order
        Order memory orderB = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: orderA.expiredTime - MIN_DIFFERENCE_BETWEEN_ORDERS
        });

        StdCheats.deal(address(PEPE), userB, INITIAL_VALUE);

        vm.startPrank(userB);

        IERC20(PEPE).approve(address(htlc), orderB.value);

        htlc.lock(orderB, secretHash);

        vm.stopPrank();
    }

    function test_redeem() external {
        _beforeEach_redeem();

        vm.prank(userA);
        htlc.redeem(secret);

        assertTrue(htlc.isSecretHashRedeemed(secretHash));
        assertEq(IERC20(PEPE).balanceOf(userA), INITIAL_VALUE);
        assertEq(IERC20(PEPE).balanceOf(address(htlc)), 0);
    }

    function test_redeem_emitRedeemed() external {
        _beforeEach_redeem();

        vm.expectEmit(true, true, true, true);
        emit Redeemed(secret, secretHash, address(PEPE), userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.redeem(secret);
    }

    function test_redeem_revertIfInvalidRecipient() external {
        address invalidRecipient = makeAddr("invalidRecipient");
        Order memory orderA = Order({
            recipient: userB,
            value: INITIAL_VALUE,
            token: NATIVE_CURRENCY,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        Order memory orderB = Order({
            recipient: invalidRecipient,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        StdCheats.deal(address(PEPE), userB, INITIAL_VALUE);

        vm.startPrank(userB);

        IERC20(PEPE).approve(address(htlc), orderB.value);

        htlc.lock(orderB, secretHash);

        vm.stopPrank();

        vm.expectRevert(HTLC.InvalidRecipient.selector);

        vm.prank(userA);
        htlc.redeem(secret);
    }

    function test_redeem_revertIfOrderExpired() external {
        _beforeEach_redeem();

        vm.warp(100 days);

        vm.expectRevert(HTLC.OrderExpired.selector);

        vm.prank(userA);
        htlc.redeem(secret);
    }

    function test_redeem_revertIfSecretHashHasRedeemed() external {
        _beforeEach_redeem();

        vm.prank(userA);
        htlc.redeem(secret);

        vm.expectRevert(HTLC.SecretHashHasRedeemed.selector);

        vm.prank(userA);
        htlc.redeem(secret);
    }

    // endregion

    // region - Claim -

    function _beforeEach_claim() private {
        // 1. UserA changes ETH for PEPE of the userB
        Order memory orderA = Order({
            recipient: userB,
            value: INITIAL_VALUE,
            token: NATIVE_CURRENCY,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        // 2. UserB will fulfill userA's order
        Order memory orderB = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: orderA.expiredTime - MIN_DIFFERENCE_BETWEEN_ORDERS
        });

        StdCheats.deal(address(PEPE), userB, INITIAL_VALUE);

        vm.startPrank(userB);

        IERC20(PEPE).approve(address(htlc), orderB.value);

        htlc.lock(orderB, secretHash);

        vm.stopPrank();

        // 3. UserA redeems secret phrase and fulfill orderB
        vm.prank(userA);
        htlc.redeem(secret);
    }

    function test_claim() external {
        _beforeEach_claim();

        vm.prank(userB);
        htlc.claim(secret);

        assertTrue(htlc.isSecretHashClaimed(secretHash));
        assertEq(userB.balance, INITIAL_VALUE);
        assertEq(address(htlc).balance, 0);
    }

    function test_claim_emitClaimed() external {
        _beforeEach_claim();

        vm.expectEmit(true, true, true, true);
        emit Claimed(secret, secretHash, NATIVE_CURRENCY, userB, INITIAL_VALUE);

        vm.prank(userB);
        htlc.claim(secret);
    }

    function test_claim_revertIfInvalidRecipient() external {
        address invalidRecipient = makeAddr("invalidRecipient");

        // 1. UserA changes ETH for PEPE of the userB
        Order memory orderA = Order({
            recipient: invalidRecipient,
            value: INITIAL_VALUE,
            token: NATIVE_CURRENCY,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        // 1.1 Invalid user simulate order to success redeem
        Order memory orderI = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: orderA.expiredTime - MIN_DIFFERENCE_BETWEEN_ORDERS
        });

        StdCheats.deal(address(PEPE), invalidRecipient, INITIAL_VALUE);

        vm.startPrank(invalidRecipient);

        IERC20(PEPE).approve(address(htlc), orderI.value);

        htlc.lock(orderI, secretHash);

        vm.stopPrank();

        // 2. UserB will fulfill userA's order
        Order memory orderB = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: orderA.expiredTime - MIN_DIFFERENCE_BETWEEN_ORDERS
        });

        StdCheats.deal(address(PEPE), userB, INITIAL_VALUE);

        vm.startPrank(userB);

        IERC20(PEPE).approve(address(htlc), orderB.value);

        htlc.lock(orderB, secretHash);

        vm.stopPrank();

        // 3. UserA redeems secret phrase and fulfill orderB
        vm.prank(userA);
        htlc.redeem(secret);

        vm.expectRevert(HTLC.InvalidRecipient.selector);

        vm.prank(userB);
        htlc.claim(secret);
    }

    function test_claim_revertIfSecretHashHasClaimed() external {
        _beforeEach_claim();

        vm.prank(userB);
        htlc.claim(secret);

        vm.expectRevert(HTLC.SecretHashHasClaimed.selector);

        vm.prank(userB);
        htlc.claim(secret);
    }

    // endregion

    // region - Refund -

    function _beforeEach_refund() private {
        // UserA changes ETH for PEPE of the userB
        Order memory orderA = Order({
            recipient: userB,
            value: INITIAL_VALUE,
            token: NATIVE_CURRENCY,
            expiredTime: uint64(block.timestamp) + MIN_LOCK_TIME
        });

        deal(userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.lock{value: orderA.value}(orderA, secretHash);

        // UserB will fulfill userA's order
        Order memory orderB = Order({
            recipient: userA,
            value: INITIAL_VALUE,
            token: address(PEPE),
            expiredTime: orderA.expiredTime - MIN_DIFFERENCE_BETWEEN_ORDERS
        });

        StdCheats.deal(address(PEPE), userB, INITIAL_VALUE);

        vm.startPrank(userB);

        IERC20(PEPE).approve(address(htlc), orderB.value);

        htlc.lock(orderB, secretHash);

        vm.stopPrank();

        // Move to refund available time
        vm.warp(block.timestamp + MIN_LOCK_TIME);
    }

    function test_refund() external {
        _beforeEach_refund();

        vm.prank(userA);
        htlc.refund(secretHash);

        assertTrue(htlc.isSecretHashRefunded(secretHash, userA));
        assertEq(userA.balance, INITIAL_VALUE);
        assertEq(address(htlc).balance, 0);
    }

    function test_refund_emitRefunded() external {
        _beforeEach_refund();

        vm.expectEmit(true, true, true, true);
        emit Refunded(secretHash, NATIVE_CURRENCY, userA, INITIAL_VALUE);

        vm.prank(userA);
        htlc.refund(secretHash);
    }

    function test_refund_revertIfInvalidRecipient() external {
        _beforeEach_refund();

        vm.expectRevert(HTLC.InvalidRecipient.selector);

        htlc.refund(secretHash);
    }

    function test_refund_revertIfSecretHashHasRedeemed() external {
        _beforeEach_refund();

        vm.warp(block.timestamp - MIN_LOCK_TIME);

        vm.prank(userA);
        htlc.redeem(secret);

        vm.expectRevert(HTLC.SecretHashHasRedeemed.selector);

        vm.prank(userA);
        htlc.refund(secretHash);

        vm.expectRevert(HTLC.SecretHashHasRedeemed.selector);

        vm.prank(userB);
        htlc.refund(secretHash);
    }

    function test_refund_revertIfSecretHashHasClaimed() external {
        _beforeEach_refund();

        vm.warp(block.timestamp - MIN_LOCK_TIME);

        vm.prank(userA);
        htlc.redeem(secret);

        vm.prank(userB);
        htlc.claim(secret);

        vm.expectRevert(HTLC.SecretHashHasClaimed.selector);

        vm.prank(userB);
        htlc.refund(secretHash);
    }

    function test_refund_revertIfRefundHasNotExpiredYet() external {
        _beforeEach_refund();

        vm.warp(block.timestamp - MIN_LOCK_TIME);

        vm.expectRevert(HTLC.RefundHasNotExpiredYet.selector);

        vm.prank(userA);
        htlc.refund(secretHash);
    }

    function test_refund_revertIfSecretHashHasRefunded() external {
        _beforeEach_refund();

        vm.prank(userA);
        htlc.refund(secretHash);

        vm.expectRevert(HTLC.SecretHashHasRefunded.selector);

        vm.prank(userA);
        htlc.refund(secretHash);
    }

    // endregion
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {EnglishAuction} from "../src/EnglishAuction.sol";
import {ERC721Mock as ERC721} from "./mocks/ERC721Mock.sol";

contract EnglishAuctionTest is Test {
    uint256 constant NFT_TOKEN_ID = 100;

    EnglishAuction auction;
    ERC721 nft;

    address deployer;
    address wallet;
    address auctioneer;

    function setUp() public {
        deployer = makeAddr("deployer");
        wallet = makeAddr("wallet");
        auctioneer = makeAddr("auctioneer");

        vm.startPrank(deployer);

        nft = new ERC721();
        nft.safeMint(auctioneer, NFT_TOKEN_ID);

        auction = new EnglishAuction(wallet);

        auction.grantRole(auction.AUCTIONEER_ROLE(), auctioneer);

        vm.stopPrank();
    }

    // region - Deploy -

    function test_deploy() external {
        assertTrue(auction.hasRole(auction.DEFAULT_ADMIN_ROLE(), deployer));
        assertTrue(auction.hasRole(auction.AUCTIONEER_ROLE(), auctioneer));
        assertEq(auction.getWallet(), wallet);
    }

    function test_deploy_revertIfWalletAddressZero() external {
        vm.expectRevert(EnglishAuction.WalletAddressZero.selector);

        new EnglishAuction(address(0));
    }

    // endregion

    // region - Start auction -

    function test_start() external {
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        assertEq(auction.getAuction().auctioneer, auctioneer);
        assertEq(address(auction.getAuction().nft), address(nft));
        assertEq(auction.getAuction().tokenId, NFT_TOKEN_ID);
        assertEq(auction.getAuction().start, block.timestamp);
        assertEq(auction.getAuction().duration, auction.getAuctionDuration());
    }

    function test_start_revertIfNotAuctioneer() external {
        address notAuctioneer = makeAddr("notAuctioneer");

        vm.prank(auctioneer);
        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert();

        vm.prank(notAuctioneer);
        auction.start(nft, NFT_TOKEN_ID, block.timestamp);
    }

    function test_start_revertIfAuctionHasAlreadyStarted() external {
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(EnglishAuction.AuctionHasAlreadyStarted.selector));

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();
    }

    function test_start_revertIfAuctionIncorrectStartTime(uint256 incorrectStartTime) external {
        vm.assume(incorrectStartTime < block.timestamp);

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert(abi.encodeWithSelector(EnglishAuction.AuctionIncorrectStartTime.selector));

        auction.start(nft, NFT_TOKEN_ID, incorrectStartTime);

        vm.stopPrank();
    }

    // endregion

    // region - Bid -

    function _beforeEach_bid(address participant, uint256 value) private {
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        vm.deal(participant, value);
    }

    function test_bid() external {
        address participant = makeAddr("participant");
        uint256 value = 1.5 ether;

        _beforeEach_bid(participant, value);

        vm.prank(participant);
        auction.bid{value: value}();

        assertEq(address(auction).balance, value);
        assertEq(auction.getHighestBid().account, participant);
        assertEq(auction.getHighestBid().value, value);
    }

    function test_bid_secondBid(uint256 value2) external {
        address participant1 = makeAddr("participant1");
        uint256 value1 = 1.5 ether;

        address participant2 = makeAddr("participant2");
        vm.assume(value2 > value1 && value2 < 1_000_000_000_000 ether);

        vm.deal(participant2, value2);

        _beforeEach_bid(participant1, value1);

        vm.prank(participant1);
        auction.bid{value: value1}();

        vm.prank(participant2);
        auction.bid{value: value2}();

        assertEq(address(auction).balance, value2);
        assertEq(auction.getHighestBid().account, participant2);
        assertEq(auction.getHighestBid().value, value2);
        assertEq(address(participant1).balance, value1);
    }

    function test_bid_revertIfValueNotEnough(uint256 insufficientValue2) external {
        address participant1 = makeAddr("participant1");
        uint256 value1 = 1.5 ether;

        address participant2 = makeAddr("participant2");
        vm.assume(insufficientValue2 <= value1);

        vm.deal(participant2, insufficientValue2);

        _beforeEach_bid(participant1, value1);

        vm.prank(participant1);
        auction.bid{value: value1}();

        vm.expectRevert(abi.encodeWithSelector(EnglishAuction.ValueNotEnough.selector));

        vm.prank(participant2);
        auction.bid{value: insufficientValue2}();
    }

    // endregion

    // region - Cancel auction -

    function _beforeEach_cancel(address[] memory participants, uint256[] memory values) private {
        /// Start auction
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        /// Bids
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.deal(participant, value);

            vm.prank(participant);
            auction.bid{value: value}();
        }

        /// Move to finish
        vm.warp(auction.getAuction().start + auction.getAuction().duration);
    }

    function test_cancel() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_finish(participants, values);

        vm.prank(auctioneer);
        auction.cancel();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);
        assertEq(participants[0].balance, values[0]);
        assertEq(participants[1].balance, values[1]);

        assertEq(auction.getHighestBid().account, address(0));
        assertEq(auction.getHighestBid().value, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().duration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));
    }

    function test_cancel_revertIfNotAuctioneer() external {
        address notAuctioneer = makeAddr("notAuctioneer");

        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_finish(participants, values);

        vm.expectRevert();

        vm.prank(notAuctioneer);
        auction.cancel();
    }

    function test_cancel_revertIfAuctionNotStarted() external {
        vm.expectRevert(EnglishAuction.AuctionNotStarted.selector);

        vm.prank(auctioneer);
        auction.cancel();
    }

    // endregion

    // region - Finish -

    function _beforeEach_finish(address[] memory participants, uint256[] memory values) private {
        /// Start auction
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        /// Bids
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.deal(participant, value);

            vm.prank(participant);
            auction.bid{value: value}();
        }

        /// Move to finish
        vm.warp(auction.getAuction().start + auction.getAuction().duration);
    }

    function test_finish() external {
        address finisher = makeAddr("finisher");

        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_finish(participants, values);

        vm.prank(finisher);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), participants[1]);
        assertEq(wallet.balance, values[1]);

        assertEq(auction.getHighestBid().account, address(0));
        assertEq(auction.getHighestBid().value, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().duration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));
    }

    function test_finish_without_bids() external {
        address finisher = makeAddr("finisher");

        address[] memory participants;
        uint256[] memory values;

        _beforeEach_finish(participants, values);

        vm.prank(finisher);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);
        assertEq(address(auction).balance, 0);

        assertEq(auction.getHighestBid().account, address(0));
        assertEq(auction.getHighestBid().value, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().duration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));
    }

    // endregion

    // region - Set auction duration -

    function test_setAuctionDuration() external {
        uint256 duration = 20 days;

        vm.prank(deployer);
        auction.setAuctionDuration(duration);

        assertEq(auction.getAuctionDuration(), duration);
    }

    function test_setAuctionDuration_revertIfNotDefaultAdmin() external {
        address notDeployer = makeAddr("notDeployer");
        uint256 duration = 20 days;

        vm.expectRevert();

        vm.prank(notDeployer);
        auction.setAuctionDuration(duration);
    }

    // endregion

    // region - Set wallet -

    function test_setWallet() external {
        address newWallet = makeAddr("newWallet");

        vm.prank(deployer);
        auction.setWallet(newWallet);

        assertEq(auction.getWallet(), newWallet);
    }

    function test_setWallet_revertIfNotDefaultAdmin() external {
        address notDeployer = makeAddr("notDeployer");
        address newWallet = makeAddr("newWallet");

        vm.expectRevert();

        vm.prank(notDeployer);
        auction.setWallet(newWallet);
    }

    // endregion
}

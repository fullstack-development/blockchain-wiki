// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {BlindAuction} from "../src/BlindAuction.sol";
import {ERC721Mock as ERC721} from "./mocks/ERC721Mock.sol";

contract EnglishAuctionTest is Test {
    uint256 constant NFT_TOKEN_ID = 100;

    BlindAuction auction;
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

        auction = new BlindAuction(wallet);

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
        vm.expectRevert(BlindAuction.WalletAddressZero.selector);

        new BlindAuction(address(0));
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
        assertEq(auction.getAuction().commitDuration, auction.getCommitDuration());
        assertEq(auction.getAuction().revealDuration, auction.getRevealDuration());
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

        vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionHasAlreadyStarted.selector));

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();
    }

    function test_start_revertIfAuctionIncorrectStartTime(uint256 incorrectStartTime) external {
        vm.assume(incorrectStartTime < block.timestamp);

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionIncorrectStartTime.selector));

        auction.start(nft, NFT_TOKEN_ID, incorrectStartTime);

        vm.stopPrank();
    }

    // endregion

    // region - Commit stage -

    function _beforeEach_commit() private {
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();
    }

    function test_commit() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_commit();

        bytes32[] memory blindedBids = new bytes32[](2);
        blindedBids[0] = auction.generateBlindedBid(participants[0], values[0]);
        blindedBids[1] = auction.generateBlindedBid(participants[1], values[1]);

        for (uint256 i = 0; i < blindedBids.length; i++) {
            bytes32 blindedBid = blindedBids[i];

            vm.prank(participants[i]);
            auction.commit(blindedBid);
        }

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];

            assertEq(auction.getBlindedBidByAccount(participant), blindedBids[i]);
        }
    }

    function test_commit_revertIfNotStarted() external {
        /// Создаем аукцион
        uint256 startTime = block.timestamp + 1 days;

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, startTime);

        vm.stopPrank();

        /// Commit
        uint256 value = 1.5 ether;
        address participant = makeAddr("participant");

        bytes32 blindedBid = auction.generateBlindedBid(participant, value);
        vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionNotCommitStage.selector));

        vm.prank(participant);
        auction.commit(blindedBid);
    }

    function test_commit_revertIfCommitEnded() external {
        uint256 value = 1.5 ether;
        address participant = makeAddr("participant");

        _beforeEach_commit();

        /// Симулируем окончившуюся стадию commit
        vm.warp(block.timestamp + auction.getAuction().commitDuration + 1);

        bytes32 blindedBid = auction.generateBlindedBid(participant, value);
        vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionNotCommitStage.selector));

        vm.prank(participant);
        auction.commit(blindedBid);
    }

    function test_commit_revertIfBidHasAlreadyCommitted() external {
        uint256 value = 1.5 ether;
        address participant = makeAddr("participant");

        _beforeEach_commit();

        bytes32 blindedBid = auction.generateBlindedBid(participant, value);

        vm.prank(participant);
        auction.commit(blindedBid);

        vm.expectRevert(abi.encodeWithSelector(BlindAuction.BidHasAlreadyCommitted.selector));

        vm.prank(participant);
        auction.commit(blindedBid);
    }

    // endregion

    // region - Reveal stage -

    function _beforeEach_reveal(address[] memory participants, uint256[] memory values) private {
        /// Start auction
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        /// Commit stage
        bytes32[] memory blindedBids = new bytes32[](2);
        blindedBids[0] = auction.generateBlindedBid(participants[0], values[0]);
        blindedBids[1] = auction.generateBlindedBid(participants[1], values[1]);

        for (uint256 i = 0; i < blindedBids.length; i++) {
            bytes32 blindedBid = blindedBids[i];

            vm.deal(participants[i], values[i]);

            vm.prank(participants[i]);
            auction.commit(blindedBid);
        }
    }

    function test_reveal() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_reveal(participants, values);

        /// Move to reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.prank(participant);
            auction.reveal{value: value}();
        }

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            assertEq(auction.getRevealedBids()[i].account, participant);
            assertEq(auction.getRevealedBids()[i].value, value);
        }
    }

    function test_reveal_revertIfRevealNotStarted() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_reveal(participants, values);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionNotRevealStage.selector));

            vm.prank(participant);
            auction.reveal{value: value}();
        }
    }

    function test_reveal_revertIfRevealEnded() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_reveal(participants, values);

        /// Move out reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration + auction.getAuction().revealDuration + 1);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionNotRevealStage.selector));

            vm.prank(participant);
            auction.reveal{value: value}();
        }
    }

    function test_reveal_revertIfBidNotCommitted() external {
        address participantNotCommitted = makeAddr("participantNotCommitted");
        uint256 participantNotCommittedValue = 2 ether;
        vm.deal(participantNotCommitted, participantNotCommittedValue);

        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_reveal(participants, values);

        /// Move to reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration);

        vm.expectRevert(abi.encodeWithSelector(BlindAuction.BidNotCommitted.selector));

        vm.prank(participantNotCommitted);
        auction.reveal{value: participantNotCommittedValue}();
    }

    function test_reveal_revertIfIncorrectRevealAmount(uint256 incorrectValue) external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_reveal(participants, values);

        /// Move to reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];

            uint256 value;
            if (i == 0) {
                /// Симулируем ошибку только для первого участника
                vm.assume(incorrectValue != value);
                vm.deal(participant, incorrectValue);

                value = incorrectValue;

                vm.expectRevert(abi.encodeWithSelector(BlindAuction.IncorrectRevealAmount.selector));
            } else {
                value = values[i];
            }

            vm.prank(participant);
            auction.reveal{value: value}();
        }
    }

    // endregion

    // region - Cancel auction -

    function _beforeEach_cancel(address[] memory participants, uint256[] memory values) private {
        /// Start auction
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        /// Commit stage
        for (uint256 i = 0; i < participants.length; i++) {
            bytes32 blindedBid = auction.generateBlindedBid(participants[i], values[i]);

            vm.deal(participants[i], values[i]);

            vm.prank(participants[i]);
            auction.commit(blindedBid);
        }

        /// Reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.prank(participant);
            auction.reveal{value: value}();
        }

        /// Move to finish stage
        /// Здесь block.timestamp = commitEnd, поэтому добавляем только revealDuration
        vm.warp(block.timestamp + auction.getAuction().revealDuration);
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

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().commitDuration, 0);
        assertEq(auction.getAuction().revealDuration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));

        assertEq(auction.getBlindedBidByAccount(participants[0]), bytes32(0));
        assertEq(auction.getBlindedBidByAccount(participants[1]), bytes32(0));
        assertEq(auction.getRevealedBids().length, 0);
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
        vm.expectRevert(BlindAuction.AuctionNotStarted.selector);

        vm.prank(auctioneer);
        auction.cancel();
    }

    // endregion

    // region - Finish stage -

    function _beforeEach_finish(address[] memory participants, uint256[] memory values) private {
        /// Start auction
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp);

        vm.stopPrank();

        /// Commit stage
        for (uint256 i = 0; i < participants.length; i++) {
            bytes32 blindedBid = auction.generateBlindedBid(participants[i], values[i]);

            vm.deal(participants[i], values[i]);

            vm.prank(participants[i]);
            auction.commit(blindedBid);
        }

        /// Reveal stage
        vm.warp(block.timestamp + auction.getAuction().commitDuration);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 value = values[i];

            vm.prank(participant);
            auction.reveal{value: value}();
        }

        /// Move to finish stage
        /// Здесь block.timestamp = commitEnd, поэтому добавляем только revealDuration
        vm.warp(block.timestamp + auction.getAuction().revealDuration);
    }

    function test_finish() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_finish(participants, values);

        vm.prank(participants[1]);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), participants[1]);
        assertEq(wallet.balance, values[1]);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().commitDuration, 0);
        assertEq(auction.getAuction().revealDuration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));

        assertEq(auction.getBlindedBidByAccount(participants[0]), bytes32(0));
        assertEq(auction.getBlindedBidByAccount(participants[1]), bytes32(0));
        assertEq(auction.getRevealedBids().length, 0);
    }

    function test_finish_sameBids() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1 ether;

        _beforeEach_finish(participants, values);

        vm.prank(participants[0]);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), participants[0]);
        assertEq(wallet.balance, values[0]);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().commitDuration, 0);
        assertEq(auction.getAuction().revealDuration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));

        assertEq(auction.getBlindedBidByAccount(participants[0]), bytes32(0));
        assertEq(auction.getBlindedBidByAccount(participants[1]), bytes32(0));
        assertEq(auction.getRevealedBids().length, 0);
    }

    function test_finish_notBids() external {
        address finisher = makeAddr("finisher");

        address[] memory participants;
        uint256[] memory values;

        _beforeEach_finish(participants, values);

        vm.prank(finisher);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().commitDuration, 0);
        assertEq(auction.getAuction().revealDuration, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));

        assertEq(auction.getRevealedBids().length, 0);
    }

    function test_finish_revertIfNotFinishStage() external {
        address[] memory participants = new address[](2);
        participants[0] = makeAddr("participant1");
        participants[1] = makeAddr("participant2");

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1.5 ether;

        _beforeEach_finish(participants, values);

        vm.warp(0);

        vm.expectRevert(abi.encodeWithSelector(BlindAuction.AuctionNotFinishStage.selector));

        vm.prank(participants[1]);
        auction.finish();
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

    // region - Set commit duration -

    function test_setCommitDuration() external {
        uint256 commitDuration = 2 days;

        vm.prank(deployer);
        auction.setCommitDuration(commitDuration);

        assertEq(auction.getCommitDuration(), commitDuration);
    }

    function test_setCommitDuration_revertIfNotDefaultAdmin() external {
        address notDeployer = makeAddr("notDeployer");
        uint256 commitDuration = 2 days;

        vm.expectRevert();

        vm.prank(notDeployer);
        auction.setCommitDuration(commitDuration);
    }

    // endregion

    // region - Set reveal duration -

    function test_setRevealDuration() external {
        uint256 revealDuration = 2 days;

        vm.prank(deployer);
        auction.setRevealDuration(revealDuration);

        assertEq(auction.getRevealDuration(), revealDuration);
    }

    function test_setRevealDuration_revertIfNotDefaultAdmin() external {
        address notDeployer = makeAddr("notDeployer");
        uint256 revealDuration = 2 days;

        vm.expectRevert();

        vm.prank(notDeployer);
        auction.setRevealDuration(revealDuration);
    }

    // endregion
}

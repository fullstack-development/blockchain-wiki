// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {DutchAuction} from "../src/DutchAuction.sol";
import {ERC721Mock as ERC721} from "./mocks/ERC721Mock.sol";

contract DutchAuctionTest is Test {
    uint256 constant NFT_TOKEN_ID = 100;

    DutchAuction auction;
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

        auction = new DutchAuction(wallet);

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
        vm.expectRevert(DutchAuction.WalletAddressZero.selector);

        new DutchAuction(address(0));
    }

    // endregion

    // region - Start auction -

    function test_start() external {
        uint256 discountRatePerSecond = 1 ether;
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.stopPrank();

        assertEq(auction.getAuction().auctioneer, auctioneer);
        assertEq(address(auction.getAuction().nft), address(nft));
        assertEq(auction.getAuction().tokenId, NFT_TOKEN_ID);
        assertEq(auction.getAuction().start, block.timestamp);
        assertEq(auction.getAuction().startingPrice, auction.getStartingPrice());
        assertEq(auction.getAuction().discountRatePerSecond, discountRatePerSecond);
    }

    function test_start_revertIfNotAuctioneer() external {
        uint256 discountRatePerSecond = 1 ether;
        address notAuctioneer = makeAddr("notAuctioneer");

        vm.prank(auctioneer);
        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert();

        vm.prank(notAuctioneer);
        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);
    }

    function test_start_revertIfAuctionHasAlreadyStarted() external {
        uint256 discountRatePerSecond = 1 ether;
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.expectRevert(abi.encodeWithSelector(DutchAuction.AuctionHasAlreadyStarted.selector));

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.stopPrank();
    }

    function test_start_revertIfAuctionIncorrectStartTime(uint256 incorrectStartTime) external {
        uint256 discountRatePerSecond = 1 ether;

        vm.assume(incorrectStartTime < block.timestamp);

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert(abi.encodeWithSelector(DutchAuction.AuctionIncorrectStartTime.selector));

        auction.start(nft, NFT_TOKEN_ID, incorrectStartTime, discountRatePerSecond);

        vm.stopPrank();
    }

    function test_start_revertIfDiscountRatePerSecondNotEnough(uint256 incorrectDiscountRatePerSecond) external {
        uint256 startingPrice = 1000 ether;
        uint256 minAuctionTime = 1 hours;

        vm.assume(incorrectDiscountRatePerSecond <= startingPrice / minAuctionTime);

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        vm.expectRevert(abi.encodeWithSelector(DutchAuction.DiscountRatePerSecondNotEnough.selector));

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, incorrectDiscountRatePerSecond);

        vm.stopPrank();
    }

    // endregion

    // region - Cancel auction -

    function _beforeEach_cancel() private {
        uint256 discountRatePerSecond = 1 ether;
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.stopPrank();
    }

    function test_cancel() external {
        _beforeEach_cancel();

        vm.prank(auctioneer);
        auction.cancel();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().startingPrice, 0);
        assertEq(auction.getAuction().discountRatePerSecond, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));
    }

    function test_cancel_revertIfNotAuctioneer() external {
        address notAuctioneer = makeAddr("notAuctioneer");
        _beforeEach_cancel();

        vm.expectRevert();

        vm.prank(notAuctioneer);
        auction.cancel();
    }

    function test_cancel_revertIfAuctionNotStarted() external {
        vm.expectRevert(DutchAuction.AuctionNotStarted.selector);

        vm.prank(auctioneer);
        auction.cancel();
    }

    // endregion

    // region - Finish auction -

    function _beforeEach_finish() private returns (address winner, uint256 value) {
        winner = makeAddr("winner");
        uint256 discountRatePerSecond = 1 ether;
        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.stopPrank();

        value = auction.getPrice();

        vm.deal(winner, value);
    }

    function test_finish() external {
        (address winner, uint256 value) = _beforeEach_finish();

        uint256 price = auction.getPrice();

        vm.prank(winner);
        auction.finish{value: value}();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), winner);
        assertEq(wallet.balance, price);
        assertEq(winner.balance, 0);

        assertEq(auction.getAuction().start, 0);
        assertEq(auction.getAuction().tokenId, 0);
        assertEq(address(auction.getAuction().nft), address(0));
        assertEq(auction.getAuction().startingPrice, 0);
        assertEq(auction.getAuction().discountRatePerSecond, 0);
        assertEq(address(auction.getAuction().auctioneer), address(0));
    }

    function test_finish_refund() external {
        (address winner, uint256 value) = _beforeEach_finish();

        /// Симулируем долгое исполнение транзакции,
        /// чтобы прайс успел измениться и потребовалось вернуть лишний эфир,
        /// который был отправлен
        vm.warp(2 minutes);

        uint256 newValue = auction.getPrice();

        vm.prank(winner);
        auction.finish{value: value}();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), winner);
        assertEq(wallet.balance, newValue);
        assertEq(winner.balance, value - newValue);
    }

    function test_finish_zeroPriceAndCallAuctioneer() external {
        _beforeEach_finish();

        /// Симулируем окончание аукциона,
        /// когда стоимость нфт уменьшилась до нуля, но ее никто не выкупил
        vm.warp(1 days);

        assertEq(auction.getPrice(), 0);

        vm.prank(auctioneer);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);
    }

    function test_finish_zeroPriceAndCallAnyAddress() external {
        address anyAddress = makeAddr("AnyAddress");

        _beforeEach_finish();

        /// Симулируем окончание аукциона,
        /// когда стоимость нфт уменьшилась до нуля, но ее никто не выкупил
        vm.warp(1 days);

        assertEq(auction.getPrice(), 0);

        vm.prank(anyAddress);
        auction.finish();

        assertEq(nft.ownerOf(NFT_TOKEN_ID), auctioneer);
        assertEq(wallet.balance, 0);
    }

    function test_finish_revertIfValueNotEnough(uint256 incorrectValue) external {
        (address winner, uint256 value) = _beforeEach_finish();

        vm.assume(incorrectValue < value);

        vm.expectRevert(abi.encodeWithSelector(DutchAuction.ValueNotEnough.selector));

        vm.prank(winner);
        auction.finish{value: incorrectValue}();
    }

    // endregion

    // region - Get price -

    function test_getPrice() external {
        uint256 discountRatePerSecond = 1 ether;

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, block.timestamp, discountRatePerSecond);

        vm.stopPrank();

        assertGt(auction.getPrice(), 0);
    }

    function test_getPrice_revertIfAuctionNotStarted() external {
        uint256 discountRatePerSecond = 1 ether;
        uint256 plannedStartTime = block.timestamp + 1 days;

        vm.startPrank(auctioneer);

        nft.approve(address(auction), NFT_TOKEN_ID);

        auction.start(nft, NFT_TOKEN_ID, plannedStartTime, discountRatePerSecond);

        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(DutchAuction.AuctionNotStarted.selector));

        auction.getPrice();
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

    // region - Set starting price -

    function test_setStartingPrice() external {
        uint256 newStartingPrice = 1_0000_000e18;

        vm.prank(deployer);
        auction.setStartingPrice(newStartingPrice);

        assertEq(auction.getStartingPrice(), newStartingPrice);
    }

    function test_setStartingPrice_revertIfNotDefaultAdmin() external {
        address notDeployer = makeAddr("notDeployer");
        uint256 newStartingPrice = 1_0000_000e18;

        vm.expectRevert();

        vm.prank(notDeployer);
        auction.setStartingPrice(newStartingPrice);
    }

    // endregion
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockNft} from "./mocks/MockNft.sol";
import {MockLpNft} from "./mocks/MockLpNft.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {SimpleTransferableStaking, ILpNft} from "../src/SimpleTransferableStaking.sol";

contract SimpleTransferableStakingTest is Test {
    uint256 constant INITIAL_NFT_TOKEN_ID = 1;

    SimpleTransferableStaking public staking;
    IERC721 public nft;
    ILpNft public lpNft;

    address stakeholder;

    function setUp() external {
        lpNft = ILpNft(address(new MockLpNft()));
        nft = IERC721(address(new MockNft()));

        staking = new SimpleTransferableStaking(nft, lpNft);

        stakeholder = makeAddr("stakeholder");

        /// Create nft
        MockNft(address(nft)).mint(stakeholder, INITIAL_NFT_TOKEN_ID);

        /// Set minter role to lp nft contract
        MockLpNft(address(lpNft)).grantRole(MockLpNft(address(lpNft)).MINTER_ROLE(), address(staking));
    }

    // region - Deploy -

    function test_deploy() external {
        assertEq(staking.getNftAddress(), address(nft));
        assertEq(staking.getLpNftAddress(), address(lpNft));
    }

    // endregion

    // region - Stake nft -

    function test_stake() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(staking));
        assertEq(lpNft.ownerOf(tokenId), stakeholder);
        assertEq(lpNft.balanceOf(stakeholder), 1);
    }

    // endregion

    // region - Unstake nft -

    function _beforeEach_unstake(uint256 tokenId) private {
        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();
    }

    function test_unstake() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        _beforeEach_unstake(tokenId);

        vm.startPrank(stakeholder);

        lpNft.approve(address(staking), tokenId);

        staking.unstake(tokenId);

        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), stakeholder);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));

        lpNft.ownerOf(tokenId);
    }

    function test_unstake_revertIfStakeIsNotExist() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.expectRevert(SimpleTransferableStaking.StakeIsNotExist.selector);

        vm.prank(stakeholder);
        staking.unstake(tokenId);
    }

    function test_unstake_revertIfNotStaker() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;
        address notStaker = makeAddr("notStaker");

        _beforeEach_unstake(tokenId);

        vm.expectRevert(SimpleTransferableStaking.NotStaker.selector);

        vm.prank(notStaker);
        staking.unstake(tokenId);
    }

    // endregion

    // region - Transfer lp nft -

    function test_stake_transferLpNft_unstake() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;
        address newStaker = makeAddr("newStaker");

        _beforeEach_unstake(tokenId);

        /// Transfer lp nft
        vm.prank(stakeholder);
        lpNft.safeTransferFrom(stakeholder, newStaker, tokenId);

        /// Unstake by new stakeholder address
        vm.startPrank(newStaker);

        lpNft.approve(address(staking), tokenId);
        staking.unstake(tokenId);

        vm.stopPrank();

        /// Assertion
        assertEq(nft.ownerOf(tokenId), newStaker);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));

        lpNft.ownerOf(tokenId);

    }

    // endregion
}
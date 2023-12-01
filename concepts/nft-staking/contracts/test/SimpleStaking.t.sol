// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockNft} from "./mocks/MockNft.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {SimpleStaking} from "../src/SimpleStaking.sol";

contract SimpleStakingTest is Test {
    uint256 constant INITIAL_NFT_TOKEN_ID = 1;

    SimpleStaking public staking;
    IERC721 public nft;

    address stakeholder;

    function setUp() external {
        nft = IERC721(address(new MockNft()));

        staking = new SimpleStaking(nft);

        stakeholder = makeAddr("stakeholder");

        /// Create nft
        MockNft(address(nft)).mint(stakeholder, INITIAL_NFT_TOKEN_ID);
    }

    // region - Deploy -

    function test_deploy() external {
        assertEq(staking.getNftAddress(), address(nft));
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
        assertEq(staking.getStakerByTokenId(tokenId), stakeholder);
        assertEq(staking.getStakedNftBalance(stakeholder), 1);
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

        vm.prank(stakeholder);
        staking.unstake(tokenId);

        assertEq(nft.ownerOf(tokenId), stakeholder);
        assertEq(staking.getStakerByTokenId(tokenId), address(0));
        assertEq(staking.getStakedNftBalance(stakeholder), 0);
    }

    function test_unstake_revertIfStakeIsNotExist() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.expectRevert(SimpleStaking.StakeIsNotExist.selector);

        vm.prank(stakeholder);
        staking.unstake(tokenId);
    }

    function test_unstake_revertIfNotStaker() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;
        address notStaker = makeAddr("notStaker");

        _beforeEach_unstake(tokenId);

        vm.expectRevert(SimpleStaking.NotStaker.selector);

        vm.prank(notStaker);
        staking.unstake(tokenId);
    }

    // endregion
}
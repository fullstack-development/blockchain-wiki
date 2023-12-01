// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockNft} from "./mocks/MockNft.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {StakingWithOneTimeReward} from "../src/StakingWithOneTimeReward.sol";

contract StakingWithOneTimeRewardTest is Test {
    uint256 constant GAP_TIMESTAMP = 1;

    uint256 constant INITIAL_REWARD_AMOUNT_PER_NFT = 100;
    uint256 constant INITIAL_REWARD_BALANCE = 1_000_000e18;
    uint256 constant INITIAL_NFT_TOKEN_ID = 1;

    StakingWithOneTimeReward public staking;
    IERC20 public token;
    IERC721 public nft;

    address stakeholder;

    function setUp() public {
        token = IERC20(address(new MockToken()));
        nft = IERC721(address(new MockNft()));

        staking = new StakingWithOneTimeReward(nft, token, INITIAL_REWARD_AMOUNT_PER_NFT);

        stakeholder = makeAddr("stakeholder");

        /// Replenish the staking contract with reward tokens
        MockToken(address(token)).mint(address(staking), INITIAL_REWARD_BALANCE);

        /// Create nft
        MockNft(address(nft)).mint(stakeholder, INITIAL_NFT_TOKEN_ID);
    }

    // region - Deploy -

    function test_deploy() external {
        assertEq(staking.getRewardAmountPerNft(), INITIAL_REWARD_AMOUNT_PER_NFT);
        assertEq(staking.getRewardTokenAddress(), address(token));
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
    }

    // endregion

    // region - Unstake nft -

    function _beforeEach_unstake(uint256 tokenId) private {
        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();

        vm.warp(block.timestamp + staking.getStakeDuration() + GAP_TIMESTAMP);
    }

    function test_unstake() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        _beforeEach_unstake(tokenId);

        vm.prank(stakeholder);
        staking.unstake(tokenId);

        assertEq(nft.ownerOf(tokenId), stakeholder);
        assertEq(token.balanceOf(stakeholder), staking.getRewardAmountPerNft());
    }

    function test_unstake_revertIfStakeIsNotExist() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.expectRevert(StakingWithOneTimeReward.StakeIsNotExist.selector);

        vm.prank(stakeholder);
        staking.unstake(tokenId);
    }

    function test_unstake_revertIfNotStaker() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;
        address notStaker = makeAddr("notStaker");

        _beforeEach_unstake(tokenId);

        vm.expectRevert(StakingWithOneTimeReward.NotStaker.selector);

        vm.prank(notStaker);
        staking.unstake(tokenId);
    }

    function test_unstake_revertIfStakingTimeNotExpired() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();

        vm.expectRevert(StakingWithOneTimeReward.StakingTimeNotExpired.selector);

        vm.prank(stakeholder);
        staking.unstake(tokenId);
    }

    // endregion
}

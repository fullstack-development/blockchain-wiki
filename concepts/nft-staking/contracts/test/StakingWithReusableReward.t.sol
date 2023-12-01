// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockNft} from "./mocks/MockNft.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {StakingWithReusableReward} from "../src/StakingWithReusableReward.sol";

contract StakingWithReusableRewardTest is Test {
    uint256 constant INITIAL_REWARD_AMOUNT_PER_NFT = 100e18; // 100 токенов при точности вычислений 1e18
    uint256 constant INITIAL_REWARD_BALANCE = 1_000_000e18;
    uint256 constant INITIAL_NFT_TOKEN_ID = 1;

    StakingWithReusableReward public staking;
    IERC20 public token;
    IERC721 public nft;

    address stakeholder;

    function setUp() external {
        token = IERC20(address(new MockToken()));
        nft = IERC721(address(new MockNft()));

        staking = new StakingWithReusableReward(nft, token, INITIAL_REWARD_AMOUNT_PER_NFT);

        stakeholder = makeAddr("stakeholder");

        /// Replenish the staking contract with reward tokens
        MockToken(address(token)).mint(address(staking), INITIAL_REWARD_BALANCE);

        /// Create nft
        MockNft(address(nft)).mint(stakeholder, INITIAL_NFT_TOKEN_ID);
    }

    // region - Deploy -

    function test_deploy() external {
        assertEq(staking.getAnnualRewardAmountPerNft(), INITIAL_REWARD_AMOUNT_PER_NFT);
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
        assertEq(staking.getRewardInfo(stakeholder).lastTimeRewardUpdated, block.timestamp);
        assertEq(staking.getRewardInfo(stakeholder).tokenBalance, 1);
    }

    // endregion

    // region - Unstake nft -

    function _beforeEach_unstake(uint256 tokenId) private {
        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();

        vm.warp(block.timestamp + staking.SECS_PER_YEAR());
    }

    function test_unstake() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        _beforeEach_unstake(tokenId);

        vm.prank(stakeholder);
        staking.unstake(tokenId);

        assertEq(nft.ownerOf(tokenId), stakeholder);
        assertEq(staking.getRewardInfo(stakeholder).lastTimeRewardUpdated, block.timestamp);
        assertEq(staking.getRewardInfo(stakeholder).tokenBalance, 0);

        /// Claim

        uint256 expectedRewardAmount = staking.getRewardInfo(stakeholder).rewardAmount;
        assertEq(expectedRewardAmount, INITIAL_REWARD_AMOUNT_PER_NFT / staking.MULTIPLIER());

        vm.prank(stakeholder);
        staking.claimReward(stakeholder);

        assertEq(token.balanceOf(stakeholder), expectedRewardAmount);
    }

    function test_unstake_revertIfStakeIsNotExist() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        vm.expectRevert(StakingWithReusableReward.StakeIsNotExist.selector);

        vm.prank(stakeholder);
        staking.unstake(tokenId);
    }

    function test_unstake_revertIfNotStaker() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;
        address notStaker = makeAddr("notStaker");

        _beforeEach_unstake(tokenId);

        vm.expectRevert(StakingWithReusableReward.NotStaker.selector);

        vm.prank(notStaker);
        staking.unstake(tokenId);
    }

    // endregion

    // region - Unstake with claim reward -

    function _beforeEach_unstakeWithClaimReward(uint256 tokenId) private {
        vm.startPrank(stakeholder);

        nft.approve(address(staking), tokenId);

        staking.stake(tokenId);

        vm.stopPrank();

        vm.warp(block.timestamp + staking.SECS_PER_YEAR());
    }

    function test_unstakeWithClaimReward() external {
        uint256 tokenId = INITIAL_NFT_TOKEN_ID;

        _beforeEach_unstakeWithClaimReward(tokenId);

        vm.prank(stakeholder);
        staking.unstakeWithClaimReward(tokenId);

        assertEq(nft.ownerOf(tokenId), stakeholder);
        assertEq(staking.getRewardInfo(stakeholder).lastTimeRewardUpdated, block.timestamp);
        assertEq(staking.getRewardInfo(stakeholder).tokenBalance, 0);
        assertEq(token.balanceOf(stakeholder), INITIAL_REWARD_AMOUNT_PER_NFT / staking.MULTIPLIER());
    }

    // endregion
}
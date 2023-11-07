// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

import {MetalampGovernance, GovernorCountingSimple} from "../src/MetalampGovernance.sol";
import {VotesToken} from "../src/VotesToken.sol";
import {Whitelist} from "./mocks/Whitelist.sol";
import {SigUtils} from "./utils/SigUtils.sol";

contract MetalampGovernanceTest is Test {
    uint256 public constant INITIAL_TOTAL_SUPPLY_VOTES_TOKEN = 1_000_000_000e18;

    MetalampGovernance public governance;
    VotesToken public votesToken;
    Whitelist public whitelist;
    SigUtils internal sigUtils;

    address votesTokenTreasure = makeAddr("votesTokenTreasure");
    address governor = makeAddr("governor");
    address proposer = makeAddr("proposer");
    uint256 voterPrivateKey = 100;
    address voter = vm.addr(voterPrivateKey);

    function setUp() external {
        /// Создаем токен голосования
        vm.prank(votesTokenTreasure);
        votesToken = new VotesToken(INITIAL_TOTAL_SUPPLY_VOTES_TOKEN);

        sigUtils = new SigUtils(votesToken.DOMAIN_SEPARATOR());

        /// Создаем контракт для управления системой голосования
        vm.prank(governor);
        governance = new MetalampGovernance(IVotes(votesToken));

        /// Создаем контракт на котором будет вызывать функции через механизм голосования
        whitelist = new Whitelist(address(governance));
    }

    // region - Propose to governance -

    function test_propose() external {
        address includedToWhitelistAccount = makeAddr("includedToWhitelistAccount");

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _getWhitelistProposal(includedToWhitelistAccount);

        uint256 desiredSnapshot = governance.clock() + governance.votingDelay();

        vm.prank(proposer);
        uint256 proposalId = governance.propose(targets, values, calldatas, description);

        assertNotEq(proposalId, 0);
        assertEq(governance.proposalProposer(proposalId), proposer);
        assertEq(governance.proposalSnapshot(proposalId), desiredSnapshot);
        assertEq(uint8(governance.state(proposalId)), uint8(IGovernor.ProposalState.Pending));
    }

    // endregion

    // region - Cast vote -

    function _beforeEach_castVote() private returns (uint256 proposalId) {
        address includedToWhitelistAccount = makeAddr("includedToWhitelistAccount");

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _getWhitelistProposal(includedToWhitelistAccount);

        vm.prank(proposer);
        proposalId = governance.propose(targets, values, calldatas, description);
    }

    function test_castVote() external {
        uint256 voteAmount = 10e18;

        /// Создаем предложение
        uint256 proposalId = _beforeEach_castVote();

        uint8 support = uint8(GovernorCountingSimple.VoteType.For);

        /// Симулируем наличие токена голосования
        vm.prank(votesTokenTreasure);
        votesToken.transfer(voter, voteAmount);

        /// Делегируем токены от имени участника голосования на самого себя.
        /// Это позволит учитывать голоса при подсчете результатов голосования
        vm.prank(voter);
        votesToken.delegate(voter);

        /// Устанавливаем текущий блок на блок, когда начинается голосование по предложению
        uint256 snapshot = governance.proposalSnapshot(proposalId);
        vm.roll(snapshot + 1);

        vm.prank(voter);
        governance.castVote(proposalId, support);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governance.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
        assertEq(forVotes, voteAmount);
    }

    function test_castVoteWithDelegateBySig() external {
        address delegatee = makeAddr("delegatee");
        SigUtils.Delegation memory delegation = SigUtils.Delegation({
            delegatee: delegatee,
            nonce: votesToken.nonces(voter),
            expiry: type(uint256).max
        });

        bytes32 digest = sigUtils.getTypedDataHash(delegation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPrivateKey, digest);

        uint256 voteAmount = 10e18;

        /// Создаем предложение
        uint256 proposalId = _beforeEach_castVote();

        uint8 support = uint8(GovernorCountingSimple.VoteType.For);

        /// Симулируем наличие токена голосования
        vm.prank(votesTokenTreasure);
        votesToken.transfer(voter, voteAmount);

        /// Делегируем токены по подписи участника голосования на адрес delegatee.
        /// Это позволит учитывать голоса при подсчете результатов голосования
        votesToken.delegateBySig(
            delegation.delegatee,
            delegation.nonce,
            delegation.expiry,
            v,
            r,
            s
        );

        /// Устанавливаем текущий блок на блок, когда начинается голосование по предложению
        uint256 snapshot = governance.proposalSnapshot(proposalId);
        vm.roll(snapshot + 1);

        vm.prank(delegatee);
        governance.castVote(proposalId, support);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governance.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
        assertEq(forVotes, voteAmount);
    }

    // endregion

    // region - Execute proposal -

    function _beforeEach_execute(address includedToWhitelistAccount)
        private
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description,
            uint256 proposalId
        )
    {
        /// Stage 1. Propose

        (targets, values, calldatas, description) = _getWhitelistProposal(includedToWhitelistAccount);

        vm.prank(proposer);
        proposalId = governance.propose(targets, values, calldatas, description);

        uint8 support = uint8(GovernorCountingSimple.VoteType.For);

        /// Stage 2. Cast vote

        /// Simulate vote tokens to voter
        vm.prank(votesTokenTreasure);
        votesToken.transfer(voter, 10e18);

        vm.prank(voter);
        votesToken.delegate(voter);

        uint256 snapshot = governance.proposalSnapshot(proposalId);
        vm.roll(snapshot + 1);

        vm.prank(voter);
        governance.castVote(proposalId, support);

        /// Stage 3. Roll to propose deadline

        uint256 deadline = governance.proposalDeadline(proposalId);
        vm.roll(deadline + 1);
    }

    function test_execute() external {
        address anyParticipant = makeAddr("anyParticipant");
        address includedToWhitelistAccount = makeAddr("includedToWhitelistAccount");

        /// Создаем предложение, симулируем голосование, прокручивает текущий блок до блока окончания голосования
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description,
            uint256 proposalId
        ) = _beforeEach_execute(includedToWhitelistAccount);

        /// Интересно, но в отличие от proposal() тут необходимо хешировать описание предложения самостоятельно
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(anyParticipant);
        governance.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint8(governance.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertTrue(whitelist.isIncluded(includedToWhitelistAccount));
    }

    // endregion

    /**
     * @notice Создаем предложение для голосования,
     * которое предлагает вызывать функцию set(address) на контракте Whitelist.
     * Простыми словами, предлагаем рассмотреть на голосовании добавить новый адрес в whitelist
     */
    function _getWhitelistProposal(address account)
        private
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        description = "Proposal include account to whitelist";

        targets[0] = address(whitelist);
        calldatas[0] = abi.encodeWithSelector(Whitelist.set.selector, account);
    }
}

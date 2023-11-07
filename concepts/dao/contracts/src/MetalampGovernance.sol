// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

/**
 * @title Система голосования Metalamp
 * @notice Реализует самую базовую систему голосования на базе смарт контрактов OpenZeppelin
 * @dev Используется 4 базовых расширения:
 * - GovernorSettings. Для управления настройками
 * - GovernorCountingSimple. Для подсчета вариантов голосования
 * - GovernorVotes. Для подсчета веса голосов
 * - GovernorVotesQuorumFraction. Для управления кворумом
 */
contract MetalampGovernance is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction {
    uint48 public constant INITIAL_VOTING_DELAY = 1 days;
    uint32 public constant INITIAL_VOTING_PERIOD = 30 days;

    /// Означает, что разрешается любому аккаунту создавать предложения
    uint256 public constant INITIAL_PROPOSAL_THRESHOLD = 0;
    /// Означает, что кворум значение не учитывается в подсчете результатов
    uint256 public constant INITIAL_QUORUM_NUMERATOR_VALUE = 0;

    constructor(IVotes token)
        Governor("Metalamp governance")
        GovernorSettings(INITIAL_VOTING_DELAY, INITIAL_VOTING_PERIOD, INITIAL_PROPOSAL_THRESHOLD)
        GovernorVotes(token)
        GovernorVotesQuorumFraction(INITIAL_QUORUM_NUMERATOR_VALUE)
    {}

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}

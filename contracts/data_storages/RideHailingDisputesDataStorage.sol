// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingDisputesDataStorage is DataStorageBaseContract {
    struct Dispute {
        uint256 disputeId;
        address plaintiff;
        address defendant;
        string description;
        bool resolved;
        address[] plaintiffVoters;
        address[] defendantVoters;
    }

    Dispute[] private disputeData;

    // Sample values
    uint256 minVoterStake = 1E18 / 10;
    uint256 minPlaintiffStake = 1E18;

    function createDispute(
        address plaintiff,
        address defendant,
        string calldata description
    ) external internalContractsOnly returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(
            Dispute(
                disputeId,
                plaintiff,
                defendant,
                description,
                false,
                new address[](0),
                new address[](0)
            )
        );
        return disputeId;
    }

    function generateDisputeForVoting() external view returns (uint256) {
        // dummy oracle : get unresolved dispute by rng
        for (uint256 i = 0; i < disputeData.length; i++) {
            if (disputeData[i].resolved != true) {
                return disputeData[i].disputeId;
            }
        }

        // returns max uint256 value if no unresolved dispute found
        return (2 ^ (256 - 1));
    }

    function checkDisputeStatus(
        uint256 disputeId
    ) external view returns (bool) {
        return disputeData[disputeId].resolved;
    }

    function voteInDispute(
        uint256 disputeId,
        bool voteForPlaintiff,
        address voter
    ) external {
        if (voteForPlaintiff) {
            disputeData[disputeId].plaintiffVoters.push(voter);
        } else {
            disputeData[disputeId].defendantVoters.push(voter);
        }
    }

    function getDisputes() external view returns (Dispute[] memory) {
        return disputeData;
    }

    // function endVoting(uint256 disputeId) external view internalContractsOnly {
    //     uint256 numPlaintiffVotes = disputeData[disputeId]
    //         .plaintiffVoters
    //         .length;
    //     uint256 numDefendantVotes = disputeData[disputeId]
    //         .defendantVoters
    //         .length;
    //     address[] memory winners = new address[](0);
    //     address[] memory losers = new address[](0);
    //     address disputeLoser = new address(0);
    //     address disputeWinner = new address(0);

    //     if (numPlaintiffVotes > numDefendantVotes) {
    //         winners = disputeData[disputeId].plaintiffVoters;
    //         losers = disputeData[disputeId].plaintiffVoters;
    //     } else if (numPlaintiffVotes < numDefendantVotes) {
    //         losers = disputeData[disputeId].plaintiffVoters;
    //         winners = disputeData[disputeId].plaintiffVoters;

    //         // equal number of votes, draw
    //     } else {
    //         // do nothing
    //     }

    //     uint256 rewardPool = 0;

    //     // if not a draw
    //     if (winners.length != 0 && losers.length != 0) {
    //         // contributing stakes from voters who lost to reward pool
    //         for (uint256 i = 0; i < losers.length; i++) {
    //             accountsDataStorage.transfer(minVoterStake, losers[i], this);
    //             rewardPool += minVoterStake;
    //         }

    //         // contributing stake from loser of dispute
    //         accountsDataStorage.transfer(minPlaintiffStake, disputeLoser, this);
    //         rewardPool += minPlaintiffStake;

    //         // calculating reward per voter who won
    //         uint256 reward = rewardPool / winners.length;

    //         // distributing reward to each voter who won
    //         for (uint256 i = 0; i < winners.length; i++) {
    //             accountsDataStorage.transfer(reward, this, winners[i]);
    //         }
    //     } else {
    //         // no distribution to either side in a draw
    //     }
    // }
}

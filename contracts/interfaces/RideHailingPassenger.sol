// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";

contract RideHailingPassenger {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private disputeDataStorage;

    // Sample values
    uint256 minVoterStake = 1E18 / 10;
    uint256 minPlaintiffStake = 1E18;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress,
        RideHailingDisputesDataStorage disputeDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = ridesDataStorageAddress;
        disputeDataStorage = disputeDataStorageAddress;
    }

    function requestRide(
        uint256 bidAmount,
        string memory startLocation,
        string memory destination
    ) external payable functionalAccountOnly {
        require(
            msg.value + accountsDataStorage.getAccountBalance(msg.sender) >=
                bidAmount + accountsDataStorage.MIN_DEPOSIT_AMOUNT(),
            "Insufficient value sent"
        );
        ridesDataStorage.createRide(
            msg.sender,
            startLocation,
            destination,
            bidAmount
        );
        accountsDataStorage.addBalance(msg.value, msg.sender);
    }

    // editRide

    function acceptDriver(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.acceptByPassenger(rideId, msg.sender);
    }

    function completeRide(uint256 rideId) external functionalAccountOnly {
        uint256 fare = ridesDataStorage.getFare(rideId);
        address driver = ridesDataStorage.getDriver(rideId);
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= fare,
            "Insufficient value"
        );
        ridesDataStorage.completeByPassenger(rideId, msg.sender);
        accountsDataStorage.transfer(fare, msg.sender, driver); // driver must complete first
    }

    // create dispute
    // should we include images as well?
    function createDispute(
        address plaintiff,
        string calldata description
    ) external functionalAccountOnly returns (uint256) {
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >=
                minPlaintiffStake,
            "Insufficient value"
        );
        return
            disputeDataStorage.createDispute(
                plaintiff,
                msg.sender,
                description
            );
    }

    // need to handle case where there is no unresolved disputes
    function viewDispute()
        external
        view
        functionalAccountOnly
        returns (uint256)
    {
        return disputeDataStorage.generateDisputeForVoting();
    }

    function vote(
        uint256 disputeId,
        bool voteForPlaintiff
    ) external functionalAccountOnly {
        // min voter stake is 0.1 ETH
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= minVoterStake,
            "Insufficient value"
        );
        require(
            disputeDataStorage.checkDisputeStatus(disputeId) == false,
            "Cannot vote for resolved dispute"
        );
        disputeDataStorage.voteInDispute(
            disputeId,
            voteForPlaintiff,
            msg.sender
        );
    }

    // to be shifted to other contract
    function endVoting(uint256 disputeId) external {
        RideHailingDisputesDataStorage.Dispute[]
            memory disputes = disputeDataStorage.getDisputes();
        uint256 numPlaintiffVotes = disputes[disputeId].plaintiffVoters.length;
        uint256 numDefendantVotes = disputes[disputeId].defendantVoters.length;
        address[] memory winners = new address[](0);
        address[] memory losers = new address[](0);
        address disputeLoser = address(0);
        address disputeWinner = address(0);

        if (numPlaintiffVotes > numDefendantVotes) {
            winners = disputes[disputeId].plaintiffVoters;
            losers = disputes[disputeId].plaintiffVoters;
        } else if (numPlaintiffVotes < numDefendantVotes) {
            losers = disputes[disputeId].plaintiffVoters;
            winners = disputes[disputeId].plaintiffVoters;

            // equal number of votes, draw
        } else {
            // do nothing
        }

        uint256 rewardPool = 0;

        // if not a draw
        if (winners.length != 0 && losers.length != 0) {
            // contributing stakes from voters who lost to reward pool
            for (uint256 i = 0; i < losers.length; i++) {
                accountsDataStorage.transfer(minVoterStake, losers[i], this);
                rewardPool += minVoterStake;
            }

            // contributing stake from loser of dispute
            accountsDataStorage.transfer(minPlaintiffStake, disputeLoser, this);
            rewardPool += minPlaintiffStake;

            // calculating reward per voter who won
            uint256 reward = rewardPool / winners.length;

            // distributing reward to each voter who won
            for (uint256 i = 0; i < winners.length; i++) {
                accountsDataStorage.transfer(reward, this, winners[i]);
            }
        } else {
            // no distribution to either side in a draw
        }
    }

    modifier functionalAccountOnly() {
        require(
            accountsDataStorage.accountExists(msg.sender),
            "Account does not exist"
        );
        require(
            accountsDataStorage.accountIsFunctional(msg.sender),
            "Minimum deposit not met"
        );
        _;
    }
}

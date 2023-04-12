// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";
import "./RideHailingPassenger.sol";

contract RideDispute {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;
    RideHailingPassenger private hailingPassengerContract;

    uint public MIN_DISPUTE_AMOUNT = 1500000000000000; // when compensation from defendant is not disputed, the minimum amount to compensate voters from loser's deposit
    uint public COMPENSATION_AMOUNT = 500000000000000; // amount for defendant to compensate plantiff if plantiff wins
    uint public FULL_DISPUTE_AMOUNT = MIN_DISPUTE_AMOUNT + COMPENSATION_AMOUNT; // for disputes which compensation from defendant is disputed

    uint public VOTER_DEPOSIT_AMOUNT = 100000000000000;
    uint public constant MAX_VOTES = 50; // a dispute can only have a max of 50 votes before it automatically closes
    uint256 public MIN_VOTES_REQUIRED = 20;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage rideDataStorageAddress,
        RideHailingDisputesDataStorage disputesDataStorageAddress,
        RideHailingPassenger rideHailingPassengerAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = rideDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;
        hailingPassengerContract = rideHailingPassengerAddress;
    }

    function createDispute(
        address defendant,
        string calldata description,
        uint rideId,
        bool rideFareDisputed,
        bool compensationDisputed
    ) external returns (uint256) {
        require(
            (ridesDataStorage.getDriver(rideId) == msg.sender &&
                ridesDataStorage.getPassenger(rideId) == defendant) ||
                (ridesDataStorage.getDriver(rideId) == defendant &&
                    ridesDataStorage.getPassenger(rideId) == msg.sender),
            "Ride does not involve you and the defendant"
        );

        uint256 disputeId = disputesDataStorage.createDispute(
            msg.sender,
            defendant,
            description,
            rideId,
            rideFareDisputed,
            compensationDisputed
        );

        if (rideFareDisputed) {
            uint256 rideFare = ridesDataStorage.getFare(rideId);
            accountsDataStorage.transfer(rideFare, address(accountsDataStorage), address(this));
        }
        uint disputeAmount = MIN_DISPUTE_AMOUNT;
        if (compensationDisputed) {
            disputeAmount += COMPENSATION_AMOUNT;
        }
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= disputeAmount,
            "Account does not have enough deposit to create a dispute"
        );
        accountsDataStorage.transfer(disputeAmount, msg.sender, address(this));
        closeRide(rideId);
        return disputeId;
    }

    function getOpenDisputes() external view returns (uint256[] memory) {
        return disputesDataStorage.getOpenDisputes(msg.sender);
    }

    function giveInDispute(uint256 disputeId) external validDispute(disputeId) {
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the defendant for this dispute");
        bool rideFareDisputed = disputesDataStorage.isRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.isCompensationDisputed(disputeId);

        if (rideFareDisputed) {
            uint256 rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(
                rideFare,
                address(this),
                disputesDataStorage.getPlaintiff(disputeId)
            );
        }
        if (compensationDisputed) {
            accountsDataStorage.transfer(
                COMPENSATION_AMOUNT,
                msg.sender,
                disputesDataStorage.getPlaintiff(disputeId)
            );
        }
        disputesDataStorage.markRespondedByDefendant(disputeId);
        disputesDataStorage.setDisputeResolved(disputeId);
        reduceLoserRating(defendant);
    }

    function challengeDispute(
        uint256 disputeId,
        string calldata replyDescription
    ) external validDispute(disputeId) {
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        uint256 disputeAmount = MIN_DISPUTE_AMOUNT;
        if (disputesDataStorage.isCompensationDisputed(disputeId)) {
            disputeAmount += COMPENSATION_AMOUNT;
        }
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= disputeAmount,
            "Account does not have enough deposit to respond a dispute"
        );
        accountsDataStorage.transfer(disputeAmount, msg.sender, address(this));
        disputesDataStorage.setDefenseDescription(disputeId, replyDescription);
        disputesDataStorage.markRespondedByDefendant(disputeId);
    }

    function checkDisputeExpiry(uint256 disputeId) external validDispute(disputeId) {
        if (disputesDataStorage.getTimeRemaining(disputeId) == 0) {
            // passed 24 hour mark
            endVote(disputeId);
        }
    }

    function voteDispute(uint256 disputeId, uint8 vote) external validDispute(disputeId) {
        require(
            msg.sender != disputesDataStorage.getDefendant(disputeId) &&
                msg.sender != disputesDataStorage.getPlaintiff(disputeId),
            "You cannot vote for yourself!"
        );

        require(
            accountsDataStorage.getOverallRating(msg.sender) >= 3,
            "You need a minimum overall rating of 3 to vote"
        );

        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= VOTER_DEPOSIT_AMOUNT,
            "Your balance is lower than the voter deposit amount required to vote"
        );

        require(
            disputesDataStorage.hasVoted(msg.sender, disputeId) == false,
            "You have already voted on this dispute"
        );

        // 1 = plaintiff, 2 = defendant
        require(vote == 1 || vote == 2, "Invalid vote, input 1 for plantiff and 2 for defendant");
        if (vote == 1) {
            disputesDataStorage.increasePlaintiffVotes(disputeId, msg.sender); //must add msg.sender to voterlist to avoid repeated votes
        } else {
            disputesDataStorage.increaseDefendantVotes(disputeId, msg.sender);
        }

        accountsDataStorage.transfer(VOTER_DEPOSIT_AMOUNT, msg.sender, address(this)); //transfer voter deposit to this contract
        disputesDataStorage.recordVoterDeposit(disputeId, VOTER_DEPOSIT_AMOUNT);
        //when total vote count reaches the max
        if (
            disputesDataStorage.getDefendantVotes(disputeId) +
                disputesDataStorage.getPlaintiffVotes(disputeId) ==
            MAX_VOTES
        ) {
            endVote(disputeId);
        }
    }

    function endVote(uint256 disputeId) private validDispute(disputeId) {
        require(
            disputesDataStorage.isDisputeResolved(disputeId) == false,
            "This dispute has already been resolved!"
        );
        disputesDataStorage.setDisputeResolved(disputeId); // will set the dispute as resolved regardless of outcome

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 majorityVotesRequiredTimes1000 = ((plaintiffVotes + defendantVotes) * 3000) / 5; // 60% for majority vote, x1000 to prevent rounding errors

        address[] memory winningVoters = new address[](0);
        address winningParty;
        address losingParty;

        if (
            plaintiffVotes + defendantVotes < MIN_VOTES_REQUIRED ||
            (plaintiffVotes * 1000 < majorityVotesRequiredTimes1000 &&
                defendantVotes * 1000 < majorityVotesRequiredTimes1000)
        ) {
            // indeterminate dispute (ie. no outcome)
            // Just transfer deposited amount to defendant and plaintiff
            // voters get their own voter deposit back
            uint256 amountToReturnParties = MIN_DISPUTE_AMOUNT;
            if (disputesDataStorage.isCompensationDisputed(disputeId)) {
                amountToReturnParties += COMPENSATION_AMOUNT;
            }
            if (disputesDataStorage.isRideFareDisputed(disputeId)) {
                uint rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                amountToReturnParties += rideFare / 2;
            }
            accountsDataStorage.transfer(
                amountToReturnParties,
                address(this),
                disputesDataStorage.getPlaintiff(disputeId)
            );
            accountsDataStorage.transfer(
                amountToReturnParties,
                address(this),
                disputesDataStorage.getDefendant(disputeId)
            );
            uint[] memory voterDeposits = disputesDataStorage.getAllVotersDepositAmount(disputeId);
            address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

            for (uint i = 0; i < voters.length; i++) {
                accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); // transfer voter deposits back to individual voters
            }
        } else {
            // majority outcome has been determined
            if (plaintiffVotes * 1000 >= majorityVotesRequiredTimes1000) {
                winningParty = disputesDataStorage.getPlaintiff(disputeId);
                winningVoters = disputesDataStorage.getWinningVoters(disputeId, 1);
                losingParty = disputesDataStorage.getDefendant(disputeId);
            } else if (defendantVotes * 1000 >= majorityVotesRequiredTimes1000) {
                winningParty = disputesDataStorage.getDefendant(disputeId);
                winningVoters = disputesDataStorage.getWinningVoters(disputeId, 2);
                losingParty = disputesDataStorage.getPlaintiff(disputeId);
            }
            if (disputesDataStorage.isCompensationDisputed(disputeId)) {
                accountsDataStorage.transfer(
                    FULL_DISPUTE_AMOUNT + COMPENSATION_AMOUNT, // transfer to plaintiff the amount he deposited plus the transfer amount from defendant
                    address(this),
                    winningParty
                );
            } else {
                // only return the dispute deposit needed (amount used to split to the voters)
                accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, address(this), winningParty);
            }
            if (disputesDataStorage.isRideFareDisputed(disputeId)) {
                accountsDataStorage.transfer(
                    ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId)),
                    address(this),
                    winningParty
                );
            }
            uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
            uint256 winnerPrize = (MIN_DISPUTE_AMOUNT + totalVoterDepositAmount) /
                winningVoters.length; //transfer remaining amount minus the transfer amount to the correct voters
            for (uint256 i = 0; i < winningVoters.length; i++) {
                accountsDataStorage.transfer(winnerPrize, address(this), winningVoters[i]);
            }
            reduceLoserRating(losingParty);
        }
    }

    function reduceLoserRating(address loserAddress) internal {
        accountsDataStorage.reduceRating(loserAddress);
    }

    function checkDisputeSolved(uint256 disputeId) external view returns (bool) {
        return disputesDataStorage.isDisputeResolved(disputeId);
    }

    function getDefendant(uint256 disputeId) external view returns (address) {
        return disputesDataStorage.getDefendant(disputeId);
    }

    function getDisputeReponded(uint256 disputeId) external view returns (bool) {
        return disputesDataStorage.isDisputeRespondedByDefendant(disputeId);
    }

    function closeRide(uint256 rideId) private {
        ridesDataStorage.completeByPassenger(rideId, ridesDataStorage.getPassenger(rideId));
        ridesDataStorage.completeByDriver(rideId, ridesDataStorage.getDriver(rideId));
    }

    modifier validDispute(uint256 disputeId) {
        require(disputesDataStorage.isValidDisputeId(disputeId), "No such dispute exist!");
        _;
    }
}

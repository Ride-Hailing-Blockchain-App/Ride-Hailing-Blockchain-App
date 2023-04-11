// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";
import "./RideHailingPassenger.sol";
import "./RideDispute.sol";

contract RideDisputeLibrary {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;
    RideHailingPassenger private hailingPassengerContract;
    RideDispute private rideDispute;

    uint public MIN_DISPUTE_AMOUNT = 2000000000000000; //compensationDisputed amount + dispute deposit
    uint public TRANSFER_AMOUNT = 500000000000000; // aka compensationDisputed amount, included in the MIN_DISPUTE_AMOUNT
    uint public NONCOMPENSATION_AMOUNT = MIN_DISPUTE_AMOUNT - TRANSFER_AMOUNT; //for cases whereby there is no need for compensationDisputed, this amount is purely just for voters
    uint public VOTER_DEPOSIT_AMOUNT = 100000000000000; //Whenever a voter vote, must deposit this amount
    uint public constant MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes
    uint256 public MIN_VOTES_REQUIRED = 20;
    uint256 public MIN_VOTES_REQUIRED_TEST = 1;
    uint public constant MAX_VOTES_TEST = 3;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage rideDataStorageAddress,
        RideHailingDisputesDataStorage disputesDataStorageAddress,
        RideHailingPassenger rideHailingPassengerAddress,
        RideDispute rideDisputeAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = rideDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;
        hailingPassengerContract = rideHailingPassengerAddress;
        rideDispute = rideDisputeAddress;
    }

    //***Testing only
    function voteDisputeTest(uint256 disputeId, uint256 disputer) external validDispute(disputeId) {
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
            "You do not have enough balance to vote!"
        );

        require(
            disputesDataStorage.hasVoted(msg.sender, disputeId) == false,
            "You have already voted!"
        );

        // 1 = plaintiff, 2 = defendant
        require(disputer == 1 || disputer == 2, "Please input correct number to vote for!");
        require(disputesDataStorage.isValidDisputeId(disputeId) == true, "No such dispute exist!");
        if (disputer == 1) {
            disputesDataStorage.increasePlaintiffVotes(disputeId, msg.sender); //must add msg.sender to voterlist to avoid repeated votes
        } else {
            disputesDataStorage.increaseDefendantVotes(disputeId, msg.sender);
        }

        accountsDataStorage.transfer(VOTER_DEPOSIT_AMOUNT, msg.sender, address(rideDispute)); //transfer voter deposit to this contract
        disputesDataStorage.recordVoterDeposit(disputeId, VOTER_DEPOSIT_AMOUNT);

        //when total vote count reaches the max
        if (
            disputesDataStorage.getDefendantVotes(disputeId) +
                disputesDataStorage.getPlaintiffVotes(disputeId) ==
            MAX_VOTES_TEST
        ) {
            this.testingEndVote(disputeId);
        }
    }

    //***Testing Only
    function testingEndVote(uint256 disputeId) external {
        require(
            disputesDataStorage.isDisputeResolved(disputeId) == false,
            "This dispute has already been resolved!"
        );

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);
        bool carFareDisputed = disputesDataStorage.isRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.isCompensationDisputed(disputeId);

        // plaintiff wins if 60 percent or more belongs to plaintiff

        winners = disputesDataStorage.getWinningVoters(disputeId, 1);
        if (compensationDisputed == true) {
            accountsDataStorage.transfer(
                MIN_DISPUTE_AMOUNT + TRANSFER_AMOUNT, //transfer to plaintiff the amount he deposited plus the transfer amount from defendant
                address(rideDispute),
                disputesDataStorage.getPlaintiff(disputeId)
            );
        } else {
            //only return the dispute deposit needed (amount used to split to the voters)
            accountsDataStorage.transfer(
                NONCOMPENSATION_AMOUNT,
                address(rideDispute),
                disputesDataStorage.getPlaintiff(disputeId)
            );
        }
        if (carFareDisputed == true) {
            uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(
                carFare,
                address(rideDispute),
                disputesDataStorage.getPlaintiff(disputeId)
            );
        }
        uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
        uint256 winnerPrize = (NONCOMPENSATION_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
        for (uint256 i = 0; i < winners.length; i++) {
            accountsDataStorage.transfer(winnerPrize, address(rideDispute), winners[i]);
        }
        reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
        disputesDataStorage.setDisputeResolved(disputeId); // will set the dispute as resolved regardless of outcome
    }

    function reduceLoserRating(address loserAddress) internal {
        accountsDataStorage.reduceRating(loserAddress);
    }

    modifier validDispute(uint256 disputeId) {
        require(disputesDataStorage.isValidDisputeId(disputeId) == true, "No such dispute exist!");
        _;
    }
}

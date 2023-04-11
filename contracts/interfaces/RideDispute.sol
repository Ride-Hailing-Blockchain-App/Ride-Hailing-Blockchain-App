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
        RideHailingPassenger rideHailingPassengerAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = rideDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;
        hailingPassengerContract = rideHailingPassengerAddress;
    }


    function giveInDispute(uint256 disputeId) external validDispute(disputeId) {
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        bool carFareDisputed = disputesDataStorage.getRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.getCompensationDisputed(disputeId);

        if (carFareDisputed == true && compensationDisputed == false) {
            uint256 rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(rideFare, address(this), disputesDataStorage.getPlaintiff(disputeId));
        } else if (carFareDisputed == false && compensationDisputed == true) {
            accountsDataStorage.transfer(TRANSFER_AMOUNT, msg.sender, disputesDataStorage.getPlaintiff(disputeId));
        } else if (carFareDisputed == true && compensationDisputed == true) {
            uint256 rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(rideFare, address(this), disputesDataStorage.getPlaintiff(disputeId));
            accountsDataStorage.transfer(TRANSFER_AMOUNT, msg.sender, disputesDataStorage.getPlaintiff(disputeId));
        }
        disputesDataStorage.markResponded(disputeId);
        disputesDataStorage.setDisputeResolved(disputeId);
        reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
    }

    function returnAllVoterDeposit(uint256 disputeId) external validDispute(disputeId) {
        require(disputesDataStorage.getDisputeResolve(disputeId) == true, "Dispute is still not resolved");
        uint[] memory voterDeposits = disputesDataStorage.getAllVoterDeposit(disputeId);
        address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

        for (uint i = 0; i < voters.length; i++) {
            accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
        } 
    }

    function checkLoanExpiry(uint256 disputeId) external validDispute(disputeId) {

        if (disputesDataStorage.getTimeRemaining(disputeId) == 0) {
            // passed 24 hour mark
            this.endVote(disputeId);
        }
    }

    function voteDispute(uint256 disputeId, uint256 disputer) external validDispute(disputeId) {
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
            disputesDataStorage.checkAlreadyVoted(disputeId, msg.sender) == false,
            "You have already voted!"
        );

        // 1 = plaintiff, 2 = defendant
        require(disputer == 1 || disputer == 2, "Please input correct number to vote for!");
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        if (disputer == 1) {
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
            this.endVote(disputeId);
        }
    }

    function endVote(uint256 disputeId) external validDispute(disputeId) {
        require(
            disputesDataStorage.getDisputeResolve(disputeId) == false,
            "This dispute has already been resolved!"
        );

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);
        bool carFareDisputed = disputesDataStorage.getRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.getCompensationDisputed(disputeId);

        // TODO check floating point here, ie. 4/5 might be 0 due to casting to uint
        if (plaintiffVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED) {
            // plaintiff wins if 60 percent or more belongs to plaintiff
            winners = disputesDataStorage.won(disputeId, 1);
            if (compensationDisputed == true) {
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT + TRANSFER_AMOUNT, //transfer to plaintiff the amount he deposited plus the transfer amount from defendant
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            } else {
                //only return the dispute deposit needed (amount used to split to the voters)
                accountsDataStorage.transfer(
                    NONCOMPENSATION_AMOUNT,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            }
            if (carFareDisputed == true) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            }

            uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
            uint256 winnerPrize = (NONCOMPENSATION_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
            for (uint256 i = 0; i < winners.length; i++) {
            accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
        }
            reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
        } else if (
            defendantVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED
        ) {
            winners = disputesDataStorage.won(disputeId, 2);
            if (compensationDisputed == true) {
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT + TRANSFER_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            } else {
                accountsDataStorage.transfer(
                    NONCOMPENSATION_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }

            if (carFareDisputed == true) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }

        uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
        uint256 winnerPrize = (NONCOMPENSATION_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
        for (uint256 i = 0; i < winners.length; i++) {
            accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
        }
            reduceLoserRating(disputesDataStorage.getPlaintiff(disputeId));
        } else {
            //indeterminate dispute (ie. no outcome)
            //Just transfer deposited amount to defendant and plaintiff
            //voters get nothing back
           if (compensationDisputed == true) {
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );

            } else {
                accountsDataStorage.transfer(
                    NONCOMPENSATION_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
                accountsDataStorage.transfer(
                    NONCOMPENSATION_AMOUNT,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                ); 
            }
                if(carFareDisputed == true) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare/2,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
                accountsDataStorage.transfer(
                    carFare/2,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }
            uint[] memory voterDeposits = disputesDataStorage.getAllVoterDeposit(disputeId);
            address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

            for (uint i = 0; i < voters.length; i++) {
                accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
            } 
            
        }
        disputesDataStorage.setDisputeResolved(disputeId); // will set the dispute as resolved regardless of outcome
    }

    function reduceLoserRating(address loserAddress) internal {
        accountsDataStorage.reduceRating(loserAddress);
    }

    function checkDisputeSolved(uint256 disputeId) external view returns(bool) {
        return disputesDataStorage.getDisputeResolve(disputeId);
    }

    function getDefendant(uint256 disputeId) external view returns (address) {
        return disputesDataStorage.getDefendant(disputeId);
    }

    function getDisputeReponded(uint256 disputeId) external view returns (bool) {
        return disputesDataStorage.getResponded(disputeId);
    }

    modifier validDispute(uint256 disputeId) {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        _;
    }

}

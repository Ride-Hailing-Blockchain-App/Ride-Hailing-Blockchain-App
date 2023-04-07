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

    uint public MIN_DISPUTE_AMOUNT = 2000000000000000; //compensation amount + dispute deposit
    uint public TRANSFER_AMOUNT = 500000000000000; // aka compensation amount, included in the MIN_DISPUTE_AMOUNT
    uint public NONCOMPENSATION_AMOUNT = MIN_DISPUTE_AMOUNT - TRANSFER_AMOUNT; //for cases whereby there is no need for compensation, this amount is purely just for voters
    uint public VOTER_DEPOSIT_AMOUNT = 100000000000000; //Whenever a voter vote, must deposit this amount
    uint public constant MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes
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
        bool carFee,
        bool compensation
    ) external {
        require(
            ridesDataStorage.getDriver(rideId) == msg.sender ||
                ridesDataStorage.getPassenger(rideId) == msg.sender,
            "This ride does not belong to you!"
        );

        require(
            ridesDataStorage.getDriver(rideId) == defendant ||
                ridesDataStorage.getPassenger(rideId) == defendant,
            "This defendant is not in one of your rides!"
        );

        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DISPUTE_AMOUNT,
            "Account does not have enough deposit to create a dispute"
        );
        require(defendant != msg.sender, "You cannot make a dispute with yourself!");
        disputesDataStorage.createDispute(
            msg.sender,
            defendant,
            description,
            rideId,
            carFee,
            compensation
        );
        if (compensation == true && carFee == false) {
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(this));
        } else if (carFee == true && compensation == false) {
            hailingPassengerContract.transferRideFeeToDispute(rideId, address(this));
            accountsDataStorage.transfer(NONCOMPENSATION_AMOUNT, msg.sender, address(this));
        } else if (carFee == true && compensation == true) {
            hailingPassengerContract.transferRideFeeToDispute(rideId, address(this));
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(this));
        }
    }

    function respondDispute(uint256 disputeId, string calldata replyDescription) external {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DISPUTE_AMOUNT,
            "Account does not have enough deposit to respond a dispute"
        );
        disputesDataStorage.setDefenseDescription(disputeId, replyDescription);
        if (disputesDataStorage.getCompensationDispute(disputeId) == true) {
            //only transfer when there is dispute for compensation
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(this)); //disputeDataStorage will hold the deposit from the plaintiff
        } else {
            accountsDataStorage.transfer(NONCOMPENSATION_AMOUNT, msg.sender, address(this));
        }

        disputesDataStorage.setDisputeResponse(disputeId); 
    }

    function giveInDispute(uint256 disputeId) external {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        bool carFeeDispute = disputesDataStorage.getCarFeeDispute(disputeId);
        bool compensationDispute = disputesDataStorage.getCompensationDispute(disputeId);

        if (carFeeDispute == true && compensationDispute == false) {
            uint256 rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(rideFare, address(this), disputesDataStorage.getPlaintiff(disputeId));
        } else if (carFeeDispute == false && compensationDispute == true) {
            accountsDataStorage.transfer(TRANSFER_AMOUNT, msg.sender, disputesDataStorage.getPlaintiff(disputeId));
        } else if (carFeeDispute == true && compensationDispute == true) {
            uint256 rideFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
            accountsDataStorage.transfer(rideFare, address(this), disputesDataStorage.getPlaintiff(disputeId));
            accountsDataStorage.transfer(TRANSFER_AMOUNT, msg.sender, disputesDataStorage.getPlaintiff(disputeId));
        }

        uint[] memory voterDeposits = disputesDataStorage.getAllVoterDeposit(disputeId);
        address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

        for (uint i = 0; i < voters.length; i++) {
            accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
        } 

        disputesDataStorage.setDisputeResponse(disputeId);
        disputesDataStorage.setDisputeResolved(disputeId);
        reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
    }

    function checkLoanExpiry(uint256 disputeId) external {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");

        if (disputesDataStorage.getTimeRemaining(disputeId) == 0) {
            // passed 24 hour mark
            this.endVote(disputeId);
        }
    }

    function voteDispute(uint256 disputeId, uint256 disputer) external {
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

    function endVote(uint256 disputeId) external {
        require(
            disputesDataStorage.getDisputeResolve(disputeId) == false,
            "This dispute has already been resolved!"
        );

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);
        bool carFeeDispute = disputesDataStorage.getCarFeeDispute(disputeId);
        bool compensationDispute = disputesDataStorage.getCompensationDispute(disputeId);

        // TODO check floating point here, ie. 4/5 might be 0 due to casting to uint
        if (plaintiffVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED) {
            // plaintiff wins if 60 percent or more belongs to plaintiff
            winners = disputesDataStorage.won(disputeId, 1);
            if (compensationDispute == true) {
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
            if (carFeeDispute == true) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            }

            reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
        } else if (
            defendantVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED
        ) {
            winners = disputesDataStorage.won(disputeId, 2);
            if (compensationDispute == true) {
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

            if (carFeeDispute == true) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }

            reduceLoserRating(disputesDataStorage.getPlaintiff(disputeId));
        } else {
            //indeterminate dispute (ie. no outcome)
            //Just transfer deposited amount to defendant and plaintiff
            //voters get nothing back
            if (compensationDispute == true) {
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

                uint[] memory voterDeposits = disputesDataStorage.getAllVoterDeposit(disputeId);
                address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

                for (uint i = 0; i < voters.length; i++) {
                    accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
                }
            }
        }

        uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
        uint256 winnerPrize = (NONCOMPENSATION_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
        for (uint256 i = 0; i < winners.length; i++) {
            accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
        }

        disputesDataStorage.setDisputeResolved(disputeId); // will set the dispute as resolved regardless of outcome
    }

    function reduceLoserRating(address loserAddress) internal {
        accountsDataStorage.reduceRating(loserAddress);
    }
}

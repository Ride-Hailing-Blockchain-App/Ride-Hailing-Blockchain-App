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
    ) external {
        require(
            (ridesDataStorage.getDriver(rideId) == msg.sender &&
                ridesDataStorage.getPassenger(rideId) == defendant) ||
                (ridesDataStorage.getDriver(rideId) == defendant &&
                    ridesDataStorage.getPassenger(rideId) == msg.sender),
            "Ride does not involve you and the defendant"
        );

        disputesDataStorage.createDispute(
            msg.sender,
            defendant,
            description,
            rideId,
            rideFareDisputed,
            compensationDisputed
        );

        if (rideFareDisputed) {
            transferRideFeeToDispute(rideId);
        }
        uint disputeAmount;
        if (compensationDisputed) {
            disputeAmount = FULL_DISPUTE_AMOUNT;
        } else {
            disputeAmount = MIN_DISPUTE_AMOUNT;
        }
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= disputeAmount,
            "Account does not have enough deposit to create a dispute"
        );
        accountsDataStorage.transfer(disputeAmount, msg.sender, address(this));
    }

    function transferRideFeeToDispute(uint256 rideId) private {
        uint256 rideFare = ridesDataStorage.getFare(rideId);
        accountsDataStorage.transfer(rideFare, address(accountsDataStorage), address(this));
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
        disputesDataStorage.markResponded(disputeId);
        disputesDataStorage.setDisputeResolved(disputeId);
        reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
    }

    function returnAllVotersDeposit(uint256 disputeId) external validDispute(disputeId) {
        require(disputesDataStorage.isDisputeResolved(disputeId), "Dispute is unresolved");
        uint[] memory voterDeposits = disputesDataStorage.getAllVotersDepositAmount(disputeId);
        address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

        for (uint i = 0; i < voters.length; i++) {
            accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
        }
    }

    function checkDisputeExpiry(uint256 disputeId) external validDispute(disputeId) {
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
            disputesDataStorage.hasVoted(msg.sender, disputeId) == false,
            "You have already voted!"
        );

        // 1 = plaintiff, 2 = defendant
        require(disputer == 1 || disputer == 2, "Please input correct number to vote for!");
        require(disputesDataStorage.isValidDisputeId(disputeId), "No such dispute exist!");
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
            disputesDataStorage.isDisputeResolved(disputeId) == false,
            "This dispute has already been resolved!"
        );

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);
        bool carFareDisputed = disputesDataStorage.isRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.isCompensationDisputed(disputeId);

        // TODO check floating point here, ie. 4/5 might be 0 due to casting to uint
        if (plaintiffVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED) {
            // plaintiff wins if 60 percent or more belongs to plaintiff
            winners = disputesDataStorage.getWinningVoters(disputeId, 1);
            if (compensationDisputed) {
                accountsDataStorage.transfer(
                    FULL_DISPUTE_AMOUNT + COMPENSATION_AMOUNT, // transfer to plaintiff the amount he deposited plus the transfer amount from defendant
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            } else {
                // only return the dispute deposit needed (amount used to split to the voters)
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            }
            if (carFareDisputed) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            }

            uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
            uint256 winnerPrize = (MIN_DISPUTE_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
            for (uint256 i = 0; i < winners.length; i++) {
                accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
            }
            reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
        } else if (
            defendantVotes >= ((totalVotes * 60) / 100) && totalVotes >= MIN_VOTES_REQUIRED
        ) {
            winners = disputesDataStorage.getWinningVoters(disputeId, 2);
            if (compensationDisputed) {
                accountsDataStorage.transfer(
                    FULL_DISPUTE_AMOUNT + COMPENSATION_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            } else {
                accountsDataStorage.transfer(
                    MIN_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }

            if (carFareDisputed) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }

            uint totalVoterDepositAmount = disputesDataStorage.getTotalVoterDeposit(disputeId);
            uint256 winnerPrize = (MIN_DISPUTE_AMOUNT + totalVoterDepositAmount) / winners.length; //transfer remaining amount minus the transfer amount to the correct voters
            for (uint256 i = 0; i < winners.length; i++) {
                accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
            }
            reduceLoserRating(disputesDataStorage.getPlaintiff(disputeId));
        } else {
            //indeterminate dispute (ie. no outcome)
            //Just transfer deposited amount to defendant and plaintiff
            //voters get nothing back
            if (compensationDisputed) {
                accountsDataStorage.transfer(
                    FULL_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
                accountsDataStorage.transfer(
                    FULL_DISPUTE_AMOUNT,
                    address(this),
                    disputesDataStorage.getPlaintiff(disputeId)
                );
            } else {
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
            }
            if (carFareDisputed) {
                uint carFare = ridesDataStorage.getFare(disputesDataStorage.getRideId(disputeId));
                accountsDataStorage.transfer(
                    carFare / 2,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
                accountsDataStorage.transfer(
                    carFare / 2,
                    address(this),
                    disputesDataStorage.getDefendant(disputeId)
                );
            }
            uint[] memory voterDeposits = disputesDataStorage.getAllVotersDepositAmount(disputeId);
            address[] memory voters = disputesDataStorage.getAllVoters(disputeId);

            for (uint i = 0; i < voters.length; i++) {
                accountsDataStorage.transfer(voterDeposits[i], address(this), voters[i]); //transfer voter deposits back to individual voters
            }
        }
        disputesDataStorage.setDisputeResolved(disputeId); // will set the dispute as resolved regardless of outcome
    }

    function respondDispute(
        uint256 disputeId,
        string calldata replyDescription
    ) external validDispute(disputeId) {
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= FULL_DISPUTE_AMOUNT,
            "Account does not have enough deposit to respond a dispute"
        );
        disputesDataStorage.setDefenseDescription(disputeId, replyDescription);
        if (disputesDataStorage.isCompensationDisputed(disputeId)) {
            //only transfer when there is dispute for compensationDisputed
            accountsDataStorage.transfer(FULL_DISPUTE_AMOUNT, msg.sender, address(this)); //disputeDataStorage will hold the deposit from the plaintiff
        } else {
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(this));
        }

        disputesDataStorage.markResponded(disputeId);
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
        return disputesDataStorage.isDisputeResponded(disputeId);
    }

    modifier validDispute(uint256 disputeId) {
        require(disputesDataStorage.isValidDisputeId(disputeId), "No such dispute exist!");
        _;
    }
}

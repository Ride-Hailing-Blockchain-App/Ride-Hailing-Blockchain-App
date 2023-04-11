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

    function createDispute(
        address defendant,
        string calldata description,
        uint rideId,
        bool rideFareDisputed,
        bool compensationDisputed
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

        require(defendant != msg.sender, "You cannot make a dispute with yourself!");
        disputesDataStorage.createDispute(
            msg.sender,
            defendant,
            description,
            rideId,
            rideFareDisputed,
            compensationDisputed
        );
        if (compensationDisputed == true && rideFareDisputed == false) {
            require(
                accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DISPUTE_AMOUNT,
                "Account does not have enough deposit to create a dispute"
            );
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(rideDispute));
        } else if (rideFareDisputed == true && compensationDisputed == false) {
            require(
                accountsDataStorage.getAccountBalance(msg.sender) >= NONCOMPENSATION_AMOUNT,
                "Account does not have enough deposit to create a dispute"
            );
            hailingPassengerContract.transferRideFeeToDispute(rideId, address(rideDispute));
            accountsDataStorage.transfer(NONCOMPENSATION_AMOUNT, msg.sender, address(rideDispute)); //for the voters
        } else if (rideFareDisputed == true && compensationDisputed == true) {
            require(
                accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DISPUTE_AMOUNT,
                "Account does not have enough deposit to create a dispute"
            );
            hailingPassengerContract.transferRideFeeToDispute(rideId, address(rideDispute));
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(rideDispute));
        }
    }

    function respondDispute(uint256 disputeId, string calldata replyDescription) external validDispute(disputeId) {
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DISPUTE_AMOUNT,
            "Account does not have enough deposit to respond a dispute"
        );
        disputesDataStorage.setDefenseDescription(disputeId, replyDescription);
        if (disputesDataStorage.getCompensationDisputed(disputeId) == true) {
            //only transfer when there is dispute for compensationDisputed
            accountsDataStorage.transfer(MIN_DISPUTE_AMOUNT, msg.sender, address(rideDispute)); //disputeDataStorage will hold the deposit from the plaintiff
        } else {
            accountsDataStorage.transfer(NONCOMPENSATION_AMOUNT, msg.sender, address(rideDispute));
        }

        disputesDataStorage.markResponded(disputeId); 
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
            disputesDataStorage.getDisputeResolve(disputeId) == false,
            "This dispute has already been resolved!"
        );

        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);
        bool carFareDisputed = disputesDataStorage.getRideFareDisputed(disputeId);
        bool compensationDisputed = disputesDataStorage.getCompensationDisputed(disputeId);

            // plaintiff wins if 60 percent or more belongs to plaintiff

            winners = disputesDataStorage.won(disputeId, 1);
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
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        _;
    }
}
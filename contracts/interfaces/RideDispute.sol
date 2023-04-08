// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";

contract RideDispute {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;

    uint public MIN_DEPOSIT_AMOUNT;
    uint public constant MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage rideDataStorageAddress,
        RideHailingDisputesDataStorage disputesDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = rideDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;
        MIN_DEPOSIT_AMOUNT = accountsDataStorage.MIN_DEPOSIT_AMOUNT();
    }

    function createDispute(address defendant, string calldata description) external {
        // TODO should we also check that the defendant is in one of the plantiff's ride history?
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DEPOSIT_AMOUNT,
            "Account does not have enough deposit to create a dispute"
        );
        require(defendant != msg.sender, "You cannot make a dispute with yourself!");
        disputesDataStorage.createDispute(msg.sender, defendant, description);
        //disputeDataStorage will hold the deposits, note that this disables the account until the deposit is topped up again
        accountsDataStorage.transfer(MIN_DEPOSIT_AMOUNT, msg.sender, address(this));
    }

    function respondDispute(uint256 disputeId, string calldata replyDescription) external {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the dispute's defendant!");
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DEPOSIT_AMOUNT,
            "Account does not have enough deposit to respond a dispute"
        );
        disputesDataStorage.setDefenseDescription(disputeId, replyDescription);
        accountsDataStorage.transfer(MIN_DEPOSIT_AMOUNT, msg.sender, address(this)); //disputeDataStorage will hold the deposit from the plaintiff
    }

    function voteDispute(uint256 disputeId, uint256 disputer) external {
        require(
            msg.sender != disputesDataStorage.getDefendant(disputeId) &&
                msg.sender != disputesDataStorage.getPlaintiff(disputeId),
            "You cannot vote for yourself!"
        );

        require(
            accountsDataStorage.getOverallRating(msg.sender) >= 5,
            "You need a minimum overall rating of 5 to vote"
        );

        // 1 = plaintiff, 2 = defendant
        require(disputer == 1 || disputer == 2, "Please input correct number to vote for!");
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        if (disputer == 1) {
            disputesDataStorage.increasePlaintiffVotes(disputeId, msg.sender); //must add msg.sender to voterlist to avoid repeated votes
        } else {
            disputesDataStorage.increaseDefendantVotes(disputeId, msg.sender);
        }

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
        uint256 plaintiffVotes = disputesDataStorage.getPlaintiffVotes(disputeId);
        uint256 defendantVotes = disputesDataStorage.getDefendantVotes(disputeId);
        uint256 totalVotes = plaintiffVotes + defendantVotes;
        address[] memory winners = new address[](0);

        // TODO check floating point here, ie. 4/5 might be 0 due to casting to uint
        if (plaintiffVotes >= ((totalVotes * 3) / 5)) {
            // plaintiff wins if 60 percent or more belongs to plaintiff
            winners = disputesDataStorage.won(disputeId, 1);
            accountsDataStorage.transfer(
                MIN_DEPOSIT_AMOUNT,
                address(this),
                disputesDataStorage.getPlaintiff(disputeId)
            );

            reduceLoserRating(disputesDataStorage.getPlaintiff(disputeId));

            //need to transfer ride fee as well
        } else if (defendantVotes >= ((totalVotes * 3) / 5)) {
            winners = disputesDataStorage.won(disputeId, 2);
            accountsDataStorage.transfer(
                MIN_DEPOSIT_AMOUNT,
                address(this),
                disputesDataStorage.getDefendant(disputeId)
            );

            reduceLoserRating(disputesDataStorage.getDefendant(disputeId));
        } else {
            accountsDataStorage.transfer(
                MIN_DEPOSIT_AMOUNT,
                address(this),
                disputesDataStorage.getDefendant(disputeId)
            );
            accountsDataStorage.transfer(
                MIN_DEPOSIT_AMOUNT,
                address(this),
                disputesDataStorage.getPlaintiff(disputeId)
            );
        }

        uint256 winnerPrize = MIN_DEPOSIT_AMOUNT / winners.length;
        for (uint256 i = 0; i < winners.length; i++) {
            accountsDataStorage.transfer(winnerPrize, address(this), winners[i]);
        }
    }

    function reduceLoserRating(address loserAddress) internal {
        accountsDataStorage.reduceRating(loserAddress);
    }
}

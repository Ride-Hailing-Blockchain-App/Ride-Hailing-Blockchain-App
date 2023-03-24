// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";


contract RideDispute{
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;

    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD
    uint public constant MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes

    constructor( RideHailingAccountsDataStorage accountsDataStorageAddress, RideHailingRidesDataStorage rideDataStorageAddress, RideHailingDisputesDataStorage disputesDataStorageAddress) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = rideDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;

    }


    function createDispute(address defendant, string calldata description) external{
        require(accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DEPOSIT_AMOUNT, "Account does not have enough deposit to create a dispute");
        require(defendant != msg.sender, "You cannot make a dispute with yourself!");
        disputesDataStorage.createDispute(msg.sender, defendant, description);
        accountsDataStorage.transfer(MIN_DEPOSIT_AMOUNT, msg.sender, address(disputesDataStorage)); //disputeDataStorage will hold the deposits
    }

    function respondDispute(uint256 disputeId, string calldata replyDescription) external {
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        address defendant = disputesDataStorage.getDefendant(disputeId);
        require(msg.sender == defendant, "You are not the correct defendant!");
        require(accountsDataStorage.getAccountBalance(msg.sender) >= MIN_DEPOSIT_AMOUNT, "Account does not have enough deposit to respond a dispute");
        disputesDataStorage.setPlaintiffDescription(disputeId, replyDescription);
        accountsDataStorage.transfer(MIN_DEPOSIT_AMOUNT, msg.sender, address(disputesDataStorage)); //disputeDataStorage will hold the deposit from the plaintiff
    }

    function voteDispute(uint256 disputeId, uint256 disputer) external {
        // 1 = plaintiff, 2 = defendant
        require(disputer == 1|| disputer == 2, "Please input correct number to vote for!");
        require(disputesDataStorage.checkDisputeExist(disputeId) == true, "No such dispute exist!");
        if(disputer == 1) {
            disputesDataStorage.increasePlaintiffVotes(disputeId);
        } else {
            disputesDataStorage.increaseDefendantVotes(disputeId);
        }

        //Do up a scenario when maxvotes reached
    }

    //Do up the function for when votes end
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";

contract RideHailingAccountManagement {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingDisputesDataStorage disputesDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        disputesDataStorage = disputesDataStorageAddress;
    }

    function createAccount(string memory username) external payable {
        // TODO emit event
        require(!accountsDataStorage.accountExists(msg.sender), "Account already exists");
        require(
            msg.value >= accountsDataStorage.MIN_DEPOSIT_AMOUNT(),
            "Minimum deposit amount not met"
        );
        accountsDataStorage.createAccount(msg.sender, username, msg.value);
    }

    function getAccountBalance() external view returns (uint256) {
        require(accountsDataStorage.accountExists(msg.sender), "Account does not exist");
        return accountsDataStorage.getAccountBalance(msg.sender);
    }

    function withdrawFunds(uint256 withdrawAmt) external {
        require(accountsDataStorage.accountIsFunctional(msg.sender), "Minimum deposit not met");
        require(
            disputesDataStorage.hasActiveDispute(msg.sender),
            "Passenger cannot withdraw funds due to active dispute"
        );

        accountsDataStorage.withdrawFunds(withdrawAmt, msg.sender);
    }

    // deleteAccount? but it makes making spam accounts easier, maybe refund only 90% of deposit

    //for testing purpose
    function rateUser(uint256 score, address ratee) external {
        accountsDataStorage.rateUser(score, ratee);
    }
}

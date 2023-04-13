// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";

contract RideHailingAccountManagement {
    event AccountCreated(address userAddress);
    event FundsAdded(uint256 amountAdded);
    event FundsWithdrew(uint256 withdrawAmount);

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
        require(!accountsDataStorage.accountExists(msg.sender), "Account already exists");
        require(
            msg.value >= accountsDataStorage.MIN_DEPOSIT_AMOUNT(),
            "Minimum deposit amount not met"
        );
        accountsDataStorage.createAccount(msg.sender, username, msg.value);
        payable(address(accountsDataStorage)).transfer(msg.value);
        emit AccountCreated(msg.sender);
    }

    function addBalance() external payable {
        require(accountsDataStorage.accountExists(msg.sender), "Account does not exist");
        accountsDataStorage.addBalance(msg.value, msg.sender);
        payable(address(accountsDataStorage)).transfer(msg.value);
        emit FundsAdded(msg.value);
    }

    function getAccountBalance() external view returns (uint256) {
        require(accountsDataStorage.accountExists(msg.sender), "Account does not exist");
        return accountsDataStorage.getAccountBalance(msg.sender);
    }

    function withdrawFunds(uint256 withdrawAmt) external {
        require(accountsDataStorage.accountIsFunctional(msg.sender), "Minimum deposit not met");
        require(
            !disputesDataStorage.hasActiveDispute(msg.sender),
            "Passenger cannot withdraw funds due to active dispute"
        );
        accountsDataStorage.withdrawFunds(withdrawAmt, msg.sender);
        emit FundsWithdrew(withdrawAmt);
    }

    function getUserRating(address user) external view returns (uint256) {
        return accountsDataStorage.getOverallRating(user);
    }
}

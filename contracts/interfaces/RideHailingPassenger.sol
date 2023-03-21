// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";

contract RideHailingPassenger {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = ridesDataStorageAddress;
    }

    function requestRide(
        uint256 bidAmount,
        string memory startLocation,
        string memory destination
    ) external payable functionalAccountOnly {
        require(
            msg.value + accountsDataStorage.getAccountBalance(msg.sender) >=
                bidAmount + accountsDataStorage.MIN_DEPOSIT_AMOUNT(),
            "Insufficient value sent"
        );
        ridesDataStorage.createRide(
            msg.sender,
            startLocation,
            destination,
            bidAmount
        );
    }

    // editRide

    modifier functionalAccountOnly() {
        require(
            accountsDataStorage.accountExists(msg.sender),
            "Account does not exist"
        );
        require(
            accountsDataStorage.accountIsFunctional(msg.sender),
            "Minimum deposit not met"
        );
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./RideHailingAccounts.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";

contract RideHailingPassenger {
    RideHailingAccounts private accountsContract;
    RideHailingRidesDataStorage private ridesDataStorage;

    constructor(
        RideHailingAccounts rideHailingAccountsAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress
    ) {
        accountsContract = rideHailingAccountsAddress;
        ridesDataStorage = ridesDataStorageAddress;
    }

    function requestRide(
        uint256 bidAmount,
        string memory startLocation,
        string memory destination
    ) external payable functionalAccountOnly {
        require(
            msg.value + accountsContract.getAccountBalance(msg.sender) >=
                bidAmount + accountsContract.MIN_DEPOSIT_AMOUNT(),
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
            accountsContract.accountExists(msg.sender),
            "Account does not exist"
        );
        require(
            accountsContract.accountIsFunctional(msg.sender),
            "Minimum deposit not met"
        );
        _;
    }
}

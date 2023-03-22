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

        accountsDataStorage.add(msg.value, msg.sender);
    }

    // editRide

    function acceptDriver(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.acceptByPassenger(rideId, msg.sender);
    }

    function rideCompleted(uint256 rideId) external functionalAccountOnly {
        uint256 fare = ridesDataStorage.getFare(rideId);
        address driver = ridesDataStorage.getDriver(rideId);
        require(
            accountsDataStorage.getAccountBalance(msg.sender) >= fare,
            "Insufficient value"
        );
        ridesDataStorage.completeByPassenger(rideId, msg.sender);
        accountsDataStorage.transfer(fare, msg.sender, driver); // driver must complete first
    }

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

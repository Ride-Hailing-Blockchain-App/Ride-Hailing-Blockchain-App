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

        require(
            ridesDataStorage.hasCurrentRide(msg.sender) == false,
            "Passenger cannot request ride as previous ride has not been completed"
        );
        ridesDataStorage.createRide(msg.sender, startLocation, destination, bidAmount);
        accountsDataStorage.addBalance(msg.value, msg.sender);
    }

    // editRide

    function acceptDriver(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.acceptByPassenger(rideId, msg.sender);
    }

    function completeRide(uint256 rideId) external functionalAccountOnly {
        uint256 fare = ridesDataStorage.getFare(rideId);
        address driver = ridesDataStorage.getDriver(rideId);
        require(accountsDataStorage.getAccountBalance(msg.sender) >= fare, "Insufficient value");
        ridesDataStorage.completeByPassenger(rideId, msg.sender);
        accountsDataStorage.transfer(fare, msg.sender, driver); // driver must complete first
    }

    function rateDriver(uint256 rideId, uint256 score) external functionalAccountOnly {
        require(ridesDataStorage.rideCompleted(rideId), "Ride has not been marked as completed");

        require(score >= 0 && score <= 10, "Invalid Rating. Rating must be between 0 and 5");
        require(
            ridesDataStorage.getRatingForDriver(rideId) == 0,
            "You have rated this driver previously"
        );
        ridesDataStorage.rateDriver(rideId, score);
        address driver = ridesDataStorage.getDriver(rideId);
        accountsDataStorage.rateUser(score, driver);
    }

    modifier functionalAccountOnly() {
        require(accountsDataStorage.accountExists(msg.sender), "Account does not exist");
        require(accountsDataStorage.accountIsFunctional(msg.sender), "Minimum deposit not met");
        _;
    }
}

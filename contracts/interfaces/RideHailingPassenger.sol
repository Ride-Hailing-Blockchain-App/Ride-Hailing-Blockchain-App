// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";
import "../data_storages/RideHailingVehiclesDataStorage.sol";

contract RideHailingPassenger {
    event RideRequested(uint256 rideId, address passenger);
    event RideAcceptedByPassenger(uint256 rideId, address passenger);
    event RideCompletedByPassenger(uint256 rideId, address passenger);

    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingDisputesDataStorage private rideDisputeDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress,
        RideHailingDisputesDataStorage rideDisputeDataStorageAddress,
        RideHailingVehiclesDataStorage vehiclesDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = ridesDataStorageAddress;
        rideDisputeDataStorage = rideDisputeDataStorageAddress;
        vehiclesDataStorage = vehiclesDataStorageAddress;
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
            rideDisputeDataStorage.getNumUnrespondedDisputes(msg.sender) == 0,
            "You have yet to respond your disputes"
        );

        require(
            ridesDataStorage.hasCurrentRide(msg.sender) == false,
            "Passenger cannot request ride as previous ride has not been completed"
        );
        uint256 rideId = ridesDataStorage.createRide(
            msg.sender,
            startLocation,
            destination,
            bidAmount
        );
        accountsDataStorage.addBalance(msg.value, address(accountsDataStorage));
        emit RideRequested(rideId, msg.sender);
    }

    function getCurrentRideId() external view functionalAccountOnly returns (uint256) {
        return ridesDataStorage.getCurrentRideId(msg.sender);
    }

    function getRideStatus(
        uint256 rideId
    ) external view functionalAccountOnly returns (string memory) {
        require(
            ridesDataStorage.getPassenger(rideId) == msg.sender,
            "You are not the passenger for this ride"
        );
        if (ridesDataStorage.rideCompleted(rideId)) {
            return "Ride completed";
        } else if (ridesDataStorage.inDispute(rideId)) {
            return "In dispute";
        } else if (ridesDataStorage.isAcceptedByPassenger(rideId)) {
            return "Accepted by passenger";
        } else if (ridesDataStorage.getDriver(rideId) != address(0)) {
            return "Accepted by driver";
        } else {
            return "Looking for driver";
        }
    }

    function getVehicleInfo(
        uint256 rideId
    ) external view functionalAccountOnly returns (string memory) {
        require(
            ridesDataStorage.getPassenger(rideId) == msg.sender,
            "You are not the passenger for this ride"
        );
        address driver = ridesDataStorage.getDriver(rideId);
        require(driver != address(0), "A driver has not accepted this ride yet");
        return string.concat(
            string.concat(vehiclesDataStorage.getVehicleLicenseNumber(driver), ","), 
            vehiclesDataStorage.getVehicleModel(driver)
        );
    }

    function acceptDriver(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.acceptByPassenger(rideId, msg.sender);
        emit RideAcceptedByPassenger(rideId, msg.sender);
    }

    function completeRide(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.completeByPassenger(rideId, msg.sender);
        emit RideCompletedByPassenger(rideId, msg.sender);
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

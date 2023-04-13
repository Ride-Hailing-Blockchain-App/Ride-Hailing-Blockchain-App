// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingVehiclesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";
import "../oracles/RideHailingOracleInterface.sol";

contract RideHailingDriver {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;
    RideHailingDisputesDataStorage private rideDisputeDataStorage;
    RideHailingOracleInterface oracleInterface;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress,
        RideHailingVehiclesDataStorage vehiclesDataStorageAddress,
        RideHailingDisputesDataStorage rideDisputeDataStorageAddress,
        RideHailingOracleInterface oracleInterfaceAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = ridesDataStorageAddress;
        vehiclesDataStorage = vehiclesDataStorageAddress;
        rideDisputeDataStorage = rideDisputeDataStorageAddress;
        oracleInterface = oracleInterfaceAddress;
    }

    function registerVehicle(
        string calldata model,
        string calldata color,
        string calldata license_number
    ) external payable functionalAccountOnly {
        vehiclesDataStorage.addVehicle(msg.sender, model, color, license_number);
    }

    function getRideRequestsNearLocation(
        string calldata driverLocation
    ) external functionalAccountOnly returns (RideHailingRidesDataStorage.Ride[] memory) {
        RideHailingRidesDataStorage.Ride[] memory openRideRequests = ridesDataStorage
            .getOpenRideRequests();
        string[] memory passengerLocations = new string[](openRideRequests.length);
        for (uint i = 0; i < openRideRequests.length; i++) {
            passengerLocations[i] = openRideRequests[i].start;
        }
        uint256 numberOfRequestsDisplayed = openRideRequests.length < 5
            ? openRideRequests.length
            : 5;
        string[] memory closestPassengerLocations = oracleInterface.closestPointsToLocation(
            passengerLocations,
            driverLocation,
            numberOfRequestsDisplayed
        );

        RideHailingRidesDataStorage.Ride[]
            memory nearbyOpenRides = new RideHailingRidesDataStorage.Ride[](
                numberOfRequestsDisplayed
            );
        uint ridesPtr = 0;
        for (uint i = 0; i < openRideRequests.length; i++) {
            for (uint j = 0; j < numberOfRequestsDisplayed; j++) {
                if (
                    compareStrings(passengerLocations[i], closestPassengerLocations[j]) &&
                    ridesPtr < numberOfRequestsDisplayed
                ) {
                    nearbyOpenRides[ridesPtr] = openRideRequests[i];
                    ridesPtr++;
                }
            }
        }
        return nearbyOpenRides;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function acceptRideRequest(uint256 rideId) external functionalAccountOnly {
        require(
            rideDisputeDataStorage.getNumUnrespondedDisputes(msg.sender) == 0,
            "You have yet to respond your disputes"
        );
        ridesDataStorage.acceptByDriver(rideId, msg.sender);
    }

    // cancelRideRequest in case driver accepts accidentally? but passenger must not have accepted on their end (or do without this first to keep things simple)

    function completeRide(uint256 rideId) external functionalAccountOnly {
        uint256 fare = ridesDataStorage.getFare(rideId);
        require(
            accountsDataStorage.getAccountBalance(address(accountsDataStorage)) >= fare,
            "Passenger contract has insufficient value"
        );
        ridesDataStorage.completeByDriver(rideId, msg.sender);
        accountsDataStorage.transfer(fare, address(accountsDataStorage), msg.sender);
    }

    function ratePassenger(uint256 rideId, uint256 score) external functionalAccountOnly {
        require(ridesDataStorage.rideCompleted(rideId), "Ride has not been marked as completed");
        require(score >= 0 && score <= 10, "Invalid Rating. Rating must be between 0 and 10");
        require(
            ridesDataStorage.getRatingForPassenger(rideId) == 0,
            "You have rated this passenger previously"
        );
        ridesDataStorage.ratePassenger(rideId, score);
        address passenger = ridesDataStorage.getPassenger(rideId);
        accountsDataStorage.rateUser(score, passenger);
    }

    function getDriver(uint256 rideId) external view functionalAccountOnly returns (address) {
        return ridesDataStorage.getDriver(rideId);
    }

    function checkIfRideCompleted(
        uint256 rideId
    ) external view functionalAccountOnly returns (bool) {
        return ridesDataStorage.rideCompleted(rideId);
    }

    function getRatingForPassenger(
        uint256 rideId
    ) external view functionalAccountOnly returns (uint256) {
        return ridesDataStorage.getRatingForPassenger(rideId);
    }

    modifier functionalAccountOnly() {
        require(accountsDataStorage.accountExists(msg.sender), "Account does not exist");
        require(accountsDataStorage.accountIsFunctional(msg.sender), "Minimum deposit not met");
        _;
    }
}

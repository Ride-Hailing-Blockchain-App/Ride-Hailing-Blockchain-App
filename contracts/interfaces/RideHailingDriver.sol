// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingVehiclesDataStorage.sol";
import "../data_storages/RideHailingDisputesDataStorage.sol";

contract RideHailingDriver {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;

    constructor(
        RideHailingAccountsDataStorage accountsDataStorageAddress,
        RideHailingRidesDataStorage ridesDataStorageAddress,
        RideHailingVehiclesDataStorage vehiclesDataStorageAddress
    ) {
        accountsDataStorage = accountsDataStorageAddress;
        ridesDataStorage = ridesDataStorageAddress;
        vehiclesDataStorage = vehiclesDataStorageAddress;
    }

    function registerVehicle(
        string calldata model,
        string calldata color,
        string calldata license_number
    ) external payable functionalAccountOnly {
        vehiclesDataStorage.addVehicle(model, color, license_number);
    }

    function getRideRequestsNearLocation(
        string calldata driverLocation
    )
        external
        view
        functionalAccountOnly
        returns (RideHailingRidesDataStorage.Ride[] memory)
    {
        RideHailingRidesDataStorage.Ride[]
            memory openRideRequests = ridesDataStorage.getOpenRideRequests();
        uint256 lastIdx = 2 > openRideRequests.length
            ? openRideRequests.length
            : 2; // dummy oracle: get first two rides from list
        //TODO this should be from a separate oracle contract
        RideHailingRidesDataStorage.Ride[]
            memory nearbyOpenRides = new RideHailingRidesDataStorage.Ride[](
                lastIdx
            );
        for (uint256 i = 0; i < lastIdx; i++) {
            nearbyOpenRides[i] = openRideRequests[i];
        }
        return nearbyOpenRides;
    }

    function acceptRideRequest(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.acceptByDriver(rideId, msg.sender);
    }

    // cancelRideRequest in case driver accepts accidentally? but passenger must not have accepted on their end (or do without this first to keep things simple)

    function completeRide(uint256 rideId) external functionalAccountOnly {
        ridesDataStorage.completeByDriver(rideId, msg.sender);
    }

    function ratePassenger(
        uint256 rideId,
        uint256 score
    ) external functionalAccountOnly {
        require(
            ridesDataStorage.rideCompleted(rideId),
            "Ride has not been marked as completed"
        );
        require(
            score >= 0 && score <= 10,
            "Invalid Rating. Rating must be between 0 and 10"
        );
        require(
            ridesDataStorage.getRatingForPassenger(rideId) == 0,
            "You have rated this passenger previously"
        );
        ridesDataStorage.ratePassenger(rideId, score);
        address passenger = ridesDataStorage.getPassenger(rideId);
        accountsDataStorage.rateUser(score, passenger);
    }

    function withdrawFunds(uint256 withdrawAmt) external functionalAccountOnly {
        require(
            disputesDataStorage.hasDispute(msg.sender),
            "Driver cannot withdraw funds due to ongoing dispute"
        );

        accountsDataStorage.withdrawFunds(withdrawAmt, msg.sender);
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

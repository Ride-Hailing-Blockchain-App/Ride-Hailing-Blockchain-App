// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";
import "../data_storages/RideHailingRidesDataStorage.sol";
import "../data_storages/RideHailingVehiclesDataStorage.sol";

contract RideHailingDriver {
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;

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

    function getRideRequestsNearLocation(string calldata driverLocation)
        external
        view
        functionalAccountOnly
        returns (RideHailingRidesDataStorage.Ride[] memory)
    {
        RideHailingRidesDataStorage.Ride[] memory openRideRequests = ridesDataStorage.getOpenRideRequests();
        uint256 lastIdx = 2 > openRideRequests.length
            ? openRideRequests.length
            : 2; // dummy oracle: get first two rides from list
        //TODO this should be from a separate oracle contract
        RideHailingRidesDataStorage.Ride[] memory nearbyOpenRides = new RideHailingRidesDataStorage.Ride[](lastIdx);
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

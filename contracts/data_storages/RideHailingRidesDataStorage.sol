// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingRidesDataStorage is DataStorageBaseContract {
    struct Ride {
        uint256 rideId;
        address passenger;
        address driver; // 0 at creation
        string start; // lattitude, longitude string
        string destination;
        uint256 fare;
        bool passengerRideCompleted;
        bool driverRideCompleted;
        bool inDispute;
    }
    uint256 private rideIdCounter = 0;
    mapping(uint256 => Ride) private ridesData;

    function createRide(
        address passenger,
        string calldata start,
        string calldata destination,
        uint256 fare
    ) external internalContractsOnly returns (uint256) {
        ridesData[rideIdCounter] = Ride(
            rideIdCounter,
            passenger,
            address(0),
            start,
            destination,
            fare,
            false,
            false,
            false
        );
        return rideIdCounter++;
    }
}

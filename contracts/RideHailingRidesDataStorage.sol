// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RideHailingRidesDataStorage {
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

    constructor() {}

    function createRide(
        address passenger,
        string memory start,
        string memory destination,
        uint256 fare
    ) public {
        // TODO require msg.sender from approved contracts? `internal` doesn't work here
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
        rideIdCounter++;
    }
}

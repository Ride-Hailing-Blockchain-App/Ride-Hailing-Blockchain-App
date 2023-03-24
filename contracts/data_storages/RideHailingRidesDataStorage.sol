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
        bool acceptedByPassenger;
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
            false,
            false
        );
        return rideIdCounter++;
    }

    function getOpenRideRequests()
        external
        view
        internalContractsOnly
        returns (Ride[] memory)
    {
        // solidity does not support dynamic sized arrays in memory, so we have to calculate the size of the array first
        // can use push?
        uint256 numOpenRideRequests = 0;
        for (uint256 i = 0; i < rideIdCounter; i++) {
            if (ridesData[i].driver == address(0)) {
                numOpenRideRequests++;
            }
        }
        Ride[] memory openRides = new Ride[](numOpenRideRequests);
        uint256 j = 0;
        for (uint256 i = 0; i < rideIdCounter; i++) {
            if (ridesData[i].driver == address(0)) {
                openRides[j] = ridesData[i];
                j++;
            }
        }
        return openRides;
    }

    function acceptByDriver(
        uint256 rideId,
        address driver
    ) external internalContractsOnly validRideId(rideId) {
        ridesData[rideId].driver = driver;
    }

    function acceptByPassenger(
        uint256 rideId,
        address passenger
    )
        external
        internalContractsOnly
        validRideId(rideId)
        isPassenger(rideId, passenger)
    {
        require(
            ridesData[rideId].driver != address(0),
            "Unable to accept ride without driver"
        );
        ridesData[rideId].acceptedByPassenger = true;
    }

    function completeByPassenger(
        uint256 rideId,
        address passenger
    )
        external
        internalContractsOnly
        validRideId(rideId)
        isPassenger(rideId, passenger)
    {
        require(
            ridesData[rideId].driverRideCompleted == true,
            "Driver must complete the ride first"
        );
        ridesData[rideId].passengerRideCompleted = true;
    }

    function completeByDriver(
        uint256 rideId,
        address driver
    )
        external
        internalContractsOnly
        validRideId(rideId)
        isDriver(rideId, driver)
    {
        ridesData[rideId].driverRideCompleted = true;
    }

    function getFare(
        uint256 rideId
    )
        external
        view
        internalContractsOnly
        validRideId(rideId)
        returns (uint256)
    {
        return ridesData[rideId].fare;
    }

    function getDriver(
        uint256 rideId
    )
        external
        view
        internalContractsOnly
        validRideId(rideId)
        returns (address)
    {
        return ridesData[rideId].driver;
    }

    modifier isPassenger(uint256 rideId, address passenger) {
        require(
            ridesData[rideId].passenger == passenger,
            "User is not the passenger"
        );
        _;
    }

    modifier isDriver(uint256 rideId, address driver) {
        require(ridesData[rideId].driver == driver, "User is not the driver");
        _;
    }

    modifier validRideId(uint256 rideId) {
        require(rideId < rideIdCounter, "RideId is invalid");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RideHailingVehiclesDataStorage {
    struct Vehicle {
        uint256 vehicleId;
        string model;
        string color;
        string license_number;
    }
    Vehicle[] private vehicleData;

    constructor() {}

    function addVehicle(string memory model, string memory color, string memory license_number) public returns (uint256) {
        uint256 vehicleId = vehicleData.length;
        vehicleData.push(Vehicle(vehicleId, model, color, license_number));
        return vehicleId;
    }
}

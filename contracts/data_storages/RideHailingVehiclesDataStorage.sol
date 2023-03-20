// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingVehiclesDataStorage is DataStorageBaseContract {
    struct Vehicle {
        uint256 vehicleId;
        string model;
        string color;
        string license_number;
    }
    Vehicle[] private vehicleData;

    constructor(address ownerAddress) DataStorageBaseContract(ownerAddress) {}

    function addVehicle(
        string calldata model,
        string calldata color,
        string calldata license_number
    ) external internalContractsOnly returns (uint256) {
        uint256 vehicleId = vehicleData.length;
        vehicleData.push(Vehicle(vehicleId, model, color, license_number));
        return vehicleId;
    }
}

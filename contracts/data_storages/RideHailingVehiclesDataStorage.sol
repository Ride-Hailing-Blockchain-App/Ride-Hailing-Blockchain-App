// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingVehiclesDataStorage is DataStorageBaseContract {
    struct Vehicle {
        address driver;
        string model;
        string color;
        string license_number;
    }
    mapping(address => Vehicle) vehicleData;

    function addVehicle(
        address driver,
        string calldata model,
        string calldata color,
        string calldata license_number
    ) external internalContractsOnly {
        vehicleData[driver] = Vehicle(driver, model, color, license_number);
    }

    function getVehicleModel(
        address driver
    ) external view internalContractsOnly returns (string memory) {
        return vehicleData[driver].model;
    }

    function getVehicleColor(
        address driver
    ) external view internalContractsOnly returns (string memory) {
        return vehicleData[driver].color;
    }

    function getVehicleLicenseNumber(
        address driver
    ) external view internalContractsOnly returns (string memory) {
        return vehicleData[driver].license_number;
    }
}

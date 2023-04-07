// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/RideHailingAccountManagement.sol";
import "./interfaces/RideHailingPassenger.sol";
import "./interfaces/RideHailingDriver.sol";
import "./interfaces/RideDispute.sol";
import "./data_storages/RideHailingAccountsDataStorage.sol";
import "./data_storages/RideHailingDisputesDataStorage.sol";
import "./data_storages/RideHailingRidesDataStorage.sol";
import "./data_storages/RideHailingVehiclesDataStorage.sol";
import "./oracles/RideHailingOracleInterface.sol";

contract RideHailingApp {
    // interfaces
    RideHailingAccountManagement public accountsContract;
    RideHailingPassenger public passengerContract;
    RideHailingDriver public driverContract;
    RideDispute public disputesContract;
    RideHailingOracleInterface public oracleInterface;
    // data
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;

    constructor(RideHailingOracleInterface oracleInterfaceAddress) {
        oracleInterface = oracleInterfaceAddress;
        // initialise data storages
        accountsDataStorage = new RideHailingAccountsDataStorage();
        disputesDataStorage = new RideHailingDisputesDataStorage();
        ridesDataStorage = new RideHailingRidesDataStorage();
        vehiclesDataStorage = new RideHailingVehiclesDataStorage();
        // initialise interface contracts
        accountsContract = new RideHailingAccountManagement(
            accountsDataStorage,
            disputesDataStorage
        );
        passengerContract = new RideHailingPassenger(accountsDataStorage, ridesDataStorage, disputesDataStorage);
        driverContract = new RideHailingDriver(
            accountsDataStorage,
            ridesDataStorage,
            vehiclesDataStorage,
            disputesDataStorage,
            oracleInterface
        );
        disputesContract = new RideDispute(
            accountsDataStorage,
            ridesDataStorage,
            disputesDataStorage,
            passengerContract
        );
        address[] memory internalAddresses = new address[](5);
        internalAddresses[0] = address(this);
        internalAddresses[1] = address(accountsContract);
        internalAddresses[2] = address(passengerContract);
        internalAddresses[3] = address(driverContract);
        internalAddresses[4] = address(disputesContract);
        accountsDataStorage.setInternalContractAddresses(internalAddresses);
        disputesDataStorage.setInternalContractAddresses(internalAddresses);
        ridesDataStorage.setInternalContractAddresses(internalAddresses);
        vehiclesDataStorage.setInternalContractAddresses(internalAddresses);
    }
}

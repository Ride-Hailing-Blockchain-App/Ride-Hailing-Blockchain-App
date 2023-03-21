// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/RideHailingAccountManagement.sol";
import "./interfaces/RideHailingPassenger.sol";
import "./data_storages/RideHailingAccountsDataStorage.sol";
import "./data_storages/RideHailingDisputesDataStorage.sol";
import "./data_storages/RideHailingRidesDataStorage.sol";
import "./data_storages/RideHailingVehiclesDataStorage.sol";

contract RideHailingApp {
    // interfaces
    RideHailingAccountManagement public accountsContract;
    RideHailingPassenger public passengerContract;
    /* TODO
        RideHailingDriver driverContract // driver car management, car location updates
        RideHailingDisputeResolution disputeResolutionContract
    */

    // data
    RideHailingAccountsDataStorage private accountsDataStorage;
    RideHailingDisputesDataStorage private disputesDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;

    constructor() {
        // initialise data storages
        accountsDataStorage = new RideHailingAccountsDataStorage();
        disputesDataStorage = new RideHailingDisputesDataStorage();
        ridesDataStorage = new RideHailingRidesDataStorage();
        vehiclesDataStorage = new RideHailingVehiclesDataStorage();
        // initialise interface contracts
        accountsContract = new RideHailingAccountManagement(
            accountsDataStorage
        );
        passengerContract = new RideHailingPassenger(
            accountsDataStorage,
            ridesDataStorage
        );

        address[] memory internalAddresses = new address[](3);
        internalAddresses[0] = address(this);
        internalAddresses[1] = address(accountsContract);
        internalAddresses[2] = address(passengerContract);
        accountsDataStorage.setInternalContractAddresses(internalAddresses);
        disputesDataStorage.setInternalContractAddresses(internalAddresses);
        ridesDataStorage.setInternalContractAddresses(internalAddresses);
        vehiclesDataStorage.setInternalContractAddresses(internalAddresses);
    }
}

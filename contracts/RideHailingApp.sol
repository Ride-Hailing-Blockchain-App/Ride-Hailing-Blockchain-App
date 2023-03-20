// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/RideHailingAccounts.sol";
import "./interfaces/RideHailingPassenger.sol";
import "./data_storages/RideHailingDisputesDataStorage.sol";
import "./data_storages/RideHailingRidesDataStorage.sol";
import "./data_storages/RideHailingVehiclesDataStorage.sol";

contract RideHailingApp {
    // interfaces
    RideHailingAccounts public accountsContract;
    RideHailingPassenger public passengerContract;
    /* TODO
        RideHailingDriver driverContract // driver car management, car location updates
        RideHailingDisputeResolution disputeResolutionContract
    */

    // data
    RideHailingDisputesDataStorage private disputesDataStorage;
    RideHailingRidesDataStorage private ridesDataStorage;
    RideHailingVehiclesDataStorage private vehiclesDataStorage;

    constructor() {
        // initialise data storages
        disputesDataStorage = new RideHailingDisputesDataStorage(address(this));
        ridesDataStorage = new RideHailingRidesDataStorage(address(this));
        vehiclesDataStorage = new RideHailingVehiclesDataStorage(address(this));
        // initialise interface contracts
        accountsContract = new RideHailingAccounts();
        passengerContract = new RideHailingPassenger(
            accountsContract,
            ridesDataStorage
        );

        address[] memory internalAddresses = new address[](3);
        internalAddresses[0] = address(this);
        internalAddresses[1] = address(accountsContract);
        internalAddresses[2] = address(passengerContract);
        disputesDataStorage.setInternalContractAddresses(internalAddresses);
        ridesDataStorage.setInternalContractAddresses(internalAddresses);
        vehiclesDataStorage.setInternalContractAddresses(internalAddresses);
    }
}

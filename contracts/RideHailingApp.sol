// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./RideHailingAccounts.sol";
import "./RideHailingPassenger.sol";

import "./RideHailingDisputesDataStorage.sol";
import "./RideHailingRidesDataStorage.sol";
import "./RideHailingVehiclesDataStorage.sol";

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
        disputesDataStorage = new RideHailingDisputesDataStorage();
        ridesDataStorage = new RideHailingRidesDataStorage();
        vehiclesDataStorage = new RideHailingVehiclesDataStorage();
        // initialise interface contracts
        accountsContract = new RideHailingAccounts();
        passengerContract = new RideHailingPassenger(
            accountsContract,
            ridesDataStorage
        );
    }
}

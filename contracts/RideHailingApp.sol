// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./RideHailingAccounts.sol";
import "./RideHailingPassenger.sol";
import "./RideHailingRidesDataStorage.sol";

contract RideHailingApp {
    // interfaces
    RideHailingAccounts public accountsContract;
    RideHailingPassenger public passengerContract;

    // data
    RideHailingRidesDataStorage private ridesDataStorage;

    /* TODO
        interfaces:
        RideHailingDriver driverContract // driver car management, car location updates
        RideHailingDisputeResolution disputeResolutionContract

        data:
        RideHailingVehiclesDataStorage vehiclesDataStorage
        RideHailingDisputesDataStorage disputesDataStorage
    */

    constructor() {
        // initialise data storages
        ridesDataStorage = new RideHailingRidesDataStorage();
        // initialise interface contracts
        accountsContract = new RideHailingAccounts();
        passengerContract = new RideHailingPassenger(
            accountsContract,
            ridesDataStorage
        );
    }
}

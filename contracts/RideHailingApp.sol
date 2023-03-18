// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./RideHailingAccounts.sol";

contract RideHailingApp {
    RideHailingAccounts rideHailingAccountsContract;

    constructor(RideHailingAccounts rideHailingAccountsAddress) {
        rideHailingAccountsContract = rideHailingAccountsAddress;
    }

    modifier registeredAccountOnly() {
        require(rideHailingAccountsContract.accountExists(msg.sender));
        _;
    }


}

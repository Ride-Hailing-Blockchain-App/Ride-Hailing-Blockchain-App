// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../data_storages/RideHailingAccountsDataStorage.sol";

contract RideHailingAccountManagement {
    RideHailingAccountsDataStorage private accountsDataStorage;

    constructor(RideHailingAccountsDataStorage accountsDataStorageAddress) {
        accountsDataStorage = accountsDataStorageAddress;
    }

    function createAccount(string memory username) external payable {
        // TODO emit event
        require(
            !accountsDataStorage.accountExists(msg.sender),
            "Account already exists"
        );
        require(
            msg.value >= accountsDataStorage.MIN_DEPOSIT_AMOUNT(),
            "Minimum deposit amount not met"
        );
        accountsDataStorage.createAccount(msg.sender, username, msg.value);
    }

    function getAccountBalance() external view returns (uint256) {
        require(
            accountsDataStorage.accountExists(msg.sender),
            "Account does not exist"
        );
        return accountsDataStorage.getAccountBalance(msg.sender);
    }

    // deleteAccount? but it makes making spam accounts easier, maybe refund only 90% of deposit
}

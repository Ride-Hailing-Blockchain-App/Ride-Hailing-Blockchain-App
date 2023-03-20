// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RideHailingAccounts {
    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD

    struct UserDetails {
        string username;
        // TODO more fields
    }

    mapping(address => UserDetails) private accounts; // TODO should this be split into a data storage as well? Maybe AccountStorage and AccountManagement
    mapping(address => uint256) private accountBalances;

    constructor() {}

    function createAccount(string memory username) external payable {
        // TODO emit event
        require(!accountExists(msg.sender), "Account already exists");
        require(
            msg.value >= MIN_DEPOSIT_AMOUNT,
            "Minimum deposit amount not met"
        );
        accountBalances[msg.sender] = msg.value;
        accounts[msg.sender] = UserDetails(username);
    }

    // deleteAccount? but it makes making spam accounts easier, maybe refund only 90% of deposit

    function accountExists(address accountAddress) public view returns (bool) {
        return accountBalances[accountAddress] != 0;
    }

    function accountIsFunctional(
        address accountAddress
    ) public view returns (bool) {
        return accountBalances[accountAddress] >= MIN_DEPOSIT_AMOUNT;
    }

    function getAccountBalance(
        address accountAddress
    ) external view returns (uint256) {
        // TODO protect with msg.sender == approved contracts only
        return accountBalances[accountAddress];
    }
}

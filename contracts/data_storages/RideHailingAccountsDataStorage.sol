// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingAccountsDataStorage is DataStorageBaseContract {
    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD

    struct UserDetails {
        string username;
        // TODO more fields
    }

    mapping(address => UserDetails) private accounts;
    mapping(address => uint256) private accountBalances;

    function createAccount(
        address userAddress,
        string calldata username,
        uint256 deposit
    ) external internalContractsOnly {
        require(!accountExists(userAddress), "Account already exists");
        accountBalances[userAddress] = deposit;
        accounts[userAddress] = UserDetails(username);
    }

    function accountExists(address accountAddress) public view returns (bool) {
        return accountBalances[accountAddress] != 0;
    }

    function accountIsFunctional(
        address accountAddress
    ) external view internalContractsOnly returns (bool) {
        return accountBalances[accountAddress] >= MIN_DEPOSIT_AMOUNT;
    }

    function getAccountBalance(
        address accountAddress
    ) external view internalContractsOnly returns (uint256) {
        return accountBalances[accountAddress];
    }

    function add(
        uint256 amtToAdd,
        address accountAddress
    ) external internalContractsOnly {
        accountBalances[accountAddress] += amtToAdd;
    }

    function transfer(
        uint256 amt,
        address from,
        address to
    ) external internalContractsOnly {
        accountBalances[from] -= amt;
        accountBalances[to] += amt;
    }
}

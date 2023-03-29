// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingAccountsDataStorage is DataStorageBaseContract {
    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD

    struct UserDetails {
        string username;
        uint256[] ratings;
        uint256 overallRating;
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
        accounts[userAddress] = UserDetails(username, new uint256[](0), (0));
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

    function getOverallRating(
        address accountAddress
    ) external view returns (uint256) {
        return accounts[accountAddress].overallRating;
    }

    function addBalance(
        uint256 amount,
        address accountAddress
    ) external internalContractsOnly {
        accountBalances[accountAddress] += amount;
    }

    function rateUser(uint256 score, address accountAddress) external {
        uint256 size = accounts[accountAddress].ratings.length;
        uint256 overallRating = accounts[accountAddress].overallRating;
        overallRating = (overallRating * size + score) / (size + 1);
        accounts[accountAddress].overallRating = overallRating;
        accounts[accountAddress].ratings.push(score);
    }

    function reduceRating(address accountAddress) external {
        accounts[accountAddress].overallRating -= (uint(1) / uint(2));
    }

    function transfer(
        uint256 amount,
        address from,
        address to
    ) external internalContractsOnly {
        require(
            accountBalances[from] >= amount,
            "Insufficient account balance"
        );
        accountBalances[from] -= amount;
        accountBalances[to] += amount;
    }
}

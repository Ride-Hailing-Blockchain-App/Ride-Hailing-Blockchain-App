// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingAccountsDataStorage is DataStorageBaseContract {
    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD
    uint8 public constant MAX_USER_RATING = 10;

    struct UserDetails {
        string username;
        uint256 totalRatingSum;
        uint256 numRatings;
        uint256 overallRating;
    }

    mapping(address => UserDetails) private accounts;
    mapping(address => uint256) private accountBalances;

    function createAccount(
        address userAddress,
        string calldata username,
        uint256 deposit
    ) external payable internalContractsOnly {
        require(!accountExists(userAddress), "Account already exists");
        accountBalances[userAddress] = deposit;
        accounts[userAddress] = UserDetails(username, 0, 0, 0);
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
        require(
            score >= 0 && score <= MAX_USER_RATING,
            "Score must be an integer from 0 to 10 inclusive"
        );
        accounts[accountAddress].totalRatingSum += score;
        accounts[accountAddress].numRatings++;
        accounts[accountAddress].overallRating =
            accounts[accountAddress].totalRatingSum /
            accounts[accountAddress].numRatings;
    }

    function reduceRating(
        address accountAddress
    ) external internalContractsOnly {
        if (accounts[accountAddress].totalRatingSum < MAX_USER_RATING) {
            // subtract a full star rating
            accounts[accountAddress].totalRatingSum = 0;
        } else {
            accounts[accountAddress].totalRatingSum -= MAX_USER_RATING;
        }
        if (accounts[accountAddress].numRatings > 0) {
            // avoid division by 0
            accounts[accountAddress].overallRating =
                accounts[accountAddress].totalRatingSum /
                accounts[accountAddress].numRatings;
        }
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

    function withdrawFunds(
        uint256 amount,
        address user
    ) external internalContractsOnly {
        require(
            accountBalances[user] >= amount,
            "Insufficient account balance"
        );
        payable(user).transfer(accountBalances[user]);
        accountBalances[user] = 0;
    }
}

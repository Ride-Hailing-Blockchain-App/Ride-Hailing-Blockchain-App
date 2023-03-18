// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RideHailingAccounts {
    uint public constant MIN_DEPOSIT_AMOUNT = 20000000000000000; // about 50 SGD

    mapping(address => uint256) accountBalances;

    constructor() {
    }

    function createAccount() public payable {
        require(!accountExists(msg.sender), "Account already exists");
        require(msg.value >= MIN_DEPOSIT_AMOUNT, "Minimum deposit amount not met");
        accountBalances[msg.sender] = msg.value;
    }

    function accountExists(address accountAddress) public view returns (bool) {
        return accountBalances[accountAddress] != 0;
    }
}

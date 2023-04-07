// SPDX-License-Identifier: MIT

const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
const assert = require("assert");

const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccountManagement = artifacts.require("RideHailingAccountManagement");

const oneEth = new BigNumber(1000000000000000000);

contract("test_ride_hailing_accounts", function (accounts) {
  before(async () => {
    appInstance = await RideHailingApp.deployed();
    accountsContractAddress = await appInstance.accountsContract();
    accountsInstance = await RideHailingAccountManagement.at(accountsContractAddress);
  });
  console.log("Testing RideHailingAccounts contract");

  it("Account not exist", async function () {
    await truffleAssert.reverts(
      accountsInstance.getAccountBalance({ from: accounts[0] }),
      "Account does not exist"
    );
  });

  it("Create account", async function () {
    let createAccount = await accountsInstance.createAccount("username", {
      from: accounts[0],
      value: oneEth.dividedBy(10),
    });
    let accountBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[0] })
    );
    return assert(accountBalance.isEqualTo(oneEth.dividedBy(10)));
  });
});

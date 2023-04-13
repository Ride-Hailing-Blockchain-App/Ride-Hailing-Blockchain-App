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

  it("Cannot query balance on nonexistent account", async function () {
    await truffleAssert.reverts(
      accountsInstance.getAccountBalance({ from: accounts[0] }),
      "Account does not exist"
    );
  });

  it("Create account with insufficient deposit", async function () {
    await truffleAssert.reverts(
      accountsInstance.createAccount("username", {
        from: accounts[0],
        value: 10,
      }),
      "Minimum deposit amount not met"
    );
  });

  it("Create account successfully", async function () {
    let createAccount = await accountsInstance.createAccount("username", {
      from: accounts[0],
      value: oneEth.dividedBy(10),
    });
    truffleAssert.eventEmitted(createAccount, "AccountCreated");
    let accountBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[0] })
    );
    assert(accountBalance.isEqualTo(oneEth.dividedBy(10)));
  });

  it("Cannot create 2 accounts from same address", async function () {
    await truffleAssert.reverts(
      accountsInstance.createAccount("username", {
        from: accounts[0],
        value: oneEth.dividedBy(10),
      }),
      "Account already exists"
    );
  });

  it("Cannot withdraw more funds than current balance", async function () {
    await truffleAssert.reverts(
      accountsInstance.withdrawFunds(oneEth, {
        from: accounts[0],
      }),
      "Insufficient account balance"
    );
  });

  it("Withdraw funds successfully", async function () {
    const withdrawFunds = await accountsInstance.withdrawFunds(10, {
      from: accounts[0],
    });
    truffleAssert.eventEmitted(withdrawFunds, "FundsWithdrew");
  });
});

const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
var assert = require("assert");

var RideHailingApp = artifacts.require("../contracts/RideHailingApp.sol");
var RideHailingAccounts = artifacts.require("../contracts/interfaces/RideHailingAccounts.sol");

const oneEth = new BigNumber(1000000000000000000);

contract("test_ride_hailing_accounts", function (accounts) {
    before( async() => {
        appInstance = await RideHailingApp.deployed();
        accountsAddress = await appInstance.accountsContract();
        accountsInstance = await RideHailingAccounts.at(accountsAddress);
    });
    console.log("Testing RideHailingAccounts contract");

    it("Account not exist", async function () {
        return assert(!await accountsInstance.accountExists(accounts[0]));
    });

    it("Create account", async function () {
        let createAccount = await accountsInstance.createAccount("username", {from: accounts[0], value: oneEth.dividedBy(10)});
        return assert(await accountsInstance.accountExists(accounts[0]));
    });
});

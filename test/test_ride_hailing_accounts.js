const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
var assert = require("assert");

var RideHailingApp = artifacts.require("../contracts/RideHailingApp.sol");
var RideHailingAccounts = artifacts.require("../contracts/RideHailingAccounts.sol");

const oneEth = new BigNumber(1000000000000000000);

contract("test_ride_hailing_accounts", function (accounts) {
  console.log("Testing RideHailingAccounts contract");

  it("should assert true", async function () {
    await RideHailingAccounts.deployed();
    return assert(true);
  });
});

// SPDX-License-Identifier: MIT
const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
const assert = require("assert");

const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccountManagement = artifacts.require("RideHailingAccountManagement");
const RideHailingPassenger = artifacts.require("RideHailingPassenger");

const oneEth = new BigNumber(1000000000000000000);

contract("RideHailingPassenger", (accounts) => {
  let passenger;
  const passengerAccount = accounts[0];
  const driverAccount = accounts[1];

  before(async () => {
    appInstance = await RideHailingApp.deployed();
    accountsContractAddress = await appInstance.accountsContract();
    accountsInstance = await RideHailingAccountManagement.at(accountsContractAddress);
    passengerContractAddress = await appInstance.passengerContract();
    passengerContractInstance = await RideHailingPassenger.at(passengerContractAddress);
  });

  it("should allow passenger to request a ride successfully", async () => {
    await accountsInstance.createAccount("passenger", {
      from: passengerAccount,
      value: oneEth.dividedBy(10),
    });
    const initialBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: passengerAccount })
    );

    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    });
    const newBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: passengerAccount })
    );
    const passengerContractBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: passengerContractAddress })
    );

    // assert(
    //   newBalance.eq(initialBalance.add(web3.utils.toWei("1", "ether"))),
    //   "Passenger account balance should be increased by 1 ether"
    // );
    assert(newBalance.isEqualTo(initialBalance));
    assert(passengerContractBalance.isEqualTo(oneEth));
    // const hasRide = await ridesDataStorage.hasCurrentRide(passengerAccount);
    // assert(hasRide, "Passenger should have an ongoing ride");
  });

  // it("should fail to request a ride due to insufficient value sent", async () => {
  //   const bidAmount = web3.utils.toWei("10", "ether");
  //   const startLocation = "ABC Street";
  //   const destination = "XYZ Street";
  //   await accountsDataStorage.addBalance(bidAmount, passengerAccount);
  //   await truffleAssert.reverts(
  //     passenger.requestRide(bidAmount, startLocation, destination, {
  //       from: passengerAccount,
  //       value: web3.utils.toWei("9", "ether"),
  //     }),
  //     "Insufficient value sent"
  //   );
  // });

  // it("should fail to request a ride due to having a previous ongoing ride", async () => {
  //   const bidAmount = web3.utils.toWei("10", "ether");
  //   const startLocation = "ABC Street";
  //   const destination = "XYZ Street";
  //   await ridesDataStorage.createRide(passengerAccount, "123 Street", "456 Street", bidAmount, {
  //     from: driverAccount,
  //   });
  //   await truffleAssert.reverts(
  //     passenger.requestRide(bidAmount, startLocation, destination, {
  //       from: passengerAccount,
  //       value: web3.utils.toWei("11", "ether"),
  //     }),
  //     "Passenger cannot request ride as previous ride has not been completed"
  //   );
  // });

  // other test cases
});

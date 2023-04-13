// SPDX-License-Identifier: MIT
const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
const assert = require("assert");

const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccountManagement = artifacts.require("RideHailingAccountManagement");
const RideHailingPassenger = artifacts.require("RideHailingPassenger");
const RideHailingDriver = artifacts.require("RideHailingDriver");

const oneEth = new BigNumber(1000000000000000000);

contract("RideHailingDriver", (accounts) => {
  const passengerAccount = accounts[0];
  const driverAccount = accounts[1];

  before(async () => {
    appInstance = await RideHailingApp.deployed();
    accountsContractAddress = await appInstance.accountsContract();
    accountsInstance = await RideHailingAccountManagement.at(accountsContractAddress);
    passengerContractAddress = await appInstance.passengerContract();
    passengerContractInstance = await RideHailingPassenger.at(passengerContractAddress);
    driverContractAddress = await appInstance.driverContract();
    driverContractInstance = await RideHailingDriver.at(driverContractAddress);
  });

  it("Should allow driver to register a vehicle successfully", async () => {
    await accountsInstance.createAccount("driver", {
      from: driverAccount,
      value: oneEth.dividedBy(10),
    });

    const model = "Car Model";
    const color = "White";
    const license = "ABC123";
    truffleAssert.eventEmitted(
      await driverContractInstance.registerVehicle(model, color, license, {
        from: driverAccount,
      }),
      "VehicleRegisted"
    );
  });

  it("Should allow driver to accept a ride successfully", async () => {
    await accountsInstance.createAccount("passenger", {
      from: passengerAccount,
      value: oneEth.dividedBy(10),
    });

    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    });

    truffleAssert.eventEmitted(
      await driverContractInstance.acceptRideRequest(1, {
        from: driverAccount,
      }),
      "RideAcceptedByDriver"
    );
    const driver = await driverContractInstance.getDriver(1);
    await assert.strictEqual(driver, driverAccount, "Driver not set to driverContract");
  });

  it("Should not allow driver to accept a ride that is invalid", async () => {
    await truffleAssert.reverts(
      driverContractInstance.acceptRideRequest(2, {
        from: driverAccount,
      }),
      "RideId is invalid"
    );
  });

  it("Should not allow driver to complete a ride that is invalid", async () => {
    await truffleAssert.reverts(
      driverContractInstance.completeRide(2, {
        from: driverAccount,
      }),
      "RideId is invalid"
    );
  });

  it("Should not allow driver to rate a passenger for a ride that is incomplete", async () => {
    await truffleAssert.reverts(
      driverContractInstance.ratePassenger(1, 5, {
        from: driverAccount,
      }),
      "Ride has not been marked as completed"
    );
  });

  it("Should allow driver to complete a ride successfully", async () => {
    const initialBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: driverAccount })
    );

    await passengerContractInstance.completeRide(1, {
      from: passengerAccount,
    });
    truffleAssert.eventEmitted(
      await driverContractInstance.completeRide(1, {
        from: driverAccount,
      }),
      "RideCompletedByDriver"
    );

    const completed = await driverContractInstance.checkIfRideCompleted(1);
    const newBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: driverAccount })
    );
    await assert.strictEqual(completed, true, "Ride not completed");

    assert(newBalance.isEqualTo(initialBalance.plus(oneEth)));
  });

  it("Should not allow driver to rate a passenger with an invalid score", async () => {
    await truffleAssert.reverts(
      driverContractInstance.ratePassenger(1, 11, {
        from: driverAccount,
      }),
      "Invalid Rating. Rating must be between 0 and 10"
    );
  });

  it("Should allow driver to rate a passenger", async () => {
    await driverContractInstance.ratePassenger(1, 5, {
      from: driverAccount,
    });
    const rating = new BigNumber(await driverContractInstance.getRatingForPassenger(1));
    assert(rating.isEqualTo(new BigNumber(5)), "Rating for passenger not working");
  });

  it("should not allow driver to rate a passenger twice", async () => {
    await truffleAssert.reverts(
      driverContractInstance.ratePassenger(1, 3, {
        from: driverAccount,
      }),
      "You have rated this passenger previously"
    );
  });
});

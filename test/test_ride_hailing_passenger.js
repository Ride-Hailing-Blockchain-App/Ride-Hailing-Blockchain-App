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

contract("RideHailingPassenger", (accounts) => {
  const passengerAccount = accounts[0];
  const driverAccount = accounts[1];
  const car_model = "Car Model";
  const car_color = "White";
  const car_license = "ABC123";

  before(async () => {
    appInstance = await RideHailingApp.deployed();
    accountsContractAddress = await appInstance.accountsContract();
    accountsInstance = await RideHailingAccountManagement.at(accountsContractAddress);
    passengerContractAddress = await appInstance.passengerContract();
    passengerContractInstance = await RideHailingPassenger.at(passengerContractAddress);
    driverContractAddress = await appInstance.driverContract();
    driverContractInstance = await RideHailingDriver.at(driverContractAddress);

    await accountsInstance.createAccount("driver", {
      from: driverAccount,
      value: oneEth.dividedBy(10),
    });

    await driverContractInstance.registerVehicle(car_model, car_color, car_license, {
      from: driverAccount,
    });
  });

  it("Should allow passenger to request a ride successfully", async () => {
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
    const rideId = new BigNumber(
      await passengerContractInstance.getCurrentRideId({
        from: passengerAccount,
      })
    );
    assert.equal(
      await passengerContractInstance.getRideStatus(rideId, { from: passengerAccount }),
      "Looking for driver"
    );
  });

  it("Should fail to request a ride due to insufficient value sent", async () => {
    const bidAmount = web3.utils.toWei("10", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await truffleAssert.reverts(
      passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
        from: passengerAccount,
        value: web3.utils.toWei("9", "ether"),
      }),
      "Insufficient value sent"
    );
  });

  it("Should fail to request a ride due to having a previous ongoing ride", async () => {
    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await truffleAssert.reverts(
      passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
        from: passengerAccount,
        value: web3.utils.toWei("1", "ether"),
      }),
      "Passenger cannot request ride as previous ride has not been completed"
    );
  });

  it("Passenger can view vehicle info after driver accepts", async () => {
    const rideId = new BigNumber(
      await passengerContractInstance.getCurrentRideId({
        from: passengerAccount,
      })
    );
    await driverContractInstance.acceptRideRequest(rideId, {
      from: driverAccount,
    });
    assert.equal(await passengerContractInstance.getRideStatus(rideId), "Accepted by driver");
    const vehicleInfo = await passengerContractInstance.getVehicleInfo(rideId);
    assert.equal(vehicleInfo, car_license.concat(",", car_model));
  });

  it("Passenger can accept driver", async () => {
    const rideId = new BigNumber(
      await passengerContractInstance.getCurrentRideId({
        from: passengerAccount,
      })
    );
    truffleAssert.eventEmitted(
      await passengerContractInstance.acceptDriver(rideId),
      "RideAcceptedByPassenger"
    );
    assert.equal(
      await passengerContractInstance.getRideStatus(rideId, { from: passengerAccount }),
      "Accepted by passenger"
    );
  });

  it("Passenger can complete ride", async () => {
    const rideId = new BigNumber(
      await passengerContractInstance.getCurrentRideId({
        from: passengerAccount,
      })
    );
    truffleAssert.eventEmitted(
      await passengerContractInstance.completeRide(rideId, {
        from: passengerAccount,
      }),
      "RideCompletedByPassenger"
    );
    await driverContractInstance.completeRide(rideId, {
      from: driverAccount,
    });
    assert.equal(
      await passengerContractInstance.getRideStatus(rideId, { from: passengerAccount }),
      "Ride completed"
    );
  });

  it("Passenger can rate driver", async () => {
    assert.equal((await accountsInstance.getUserRating(driverAccount)).toNumber(), 0);
    const rating = 7;
    await passengerContractInstance.rateDriver(1, rating, {
      from: passengerAccount,
    });
    assert.equal((await accountsInstance.getUserRating(driverAccount)).toNumber(), rating);
  });
});

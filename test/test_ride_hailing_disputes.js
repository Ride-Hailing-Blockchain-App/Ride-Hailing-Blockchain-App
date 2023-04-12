// SPDX-License-Identifier: MIT

const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
const assert = require("assert");

const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccountManagement = artifacts.require("RideHailingAccountManagement");
const RideHailingPassenger = artifacts.require("RideHailingPassenger");
const RideHailingDriver = artifacts.require("RideHailingDriver");
const RideHailingDispute = artifacts.require("RideDispute");
const RideHailingDisputeLibrary = artifacts.require("RideDisputeLibrary");

const oneEth = new BigNumber(1000000000000000000);
const MIN_DISPUTE_AMOUNT = 2000000000000000; //compensationDisputed amount + dispute deposit
const TRANSFER_AMOUNT = 500000000000000; // aka compensationDisputed amount, included in the MIN_DISPUTE_AMOUNT
const NONCOMPENSATION_AMOUNT = MIN_DISPUTE_AMOUNT - TRANSFER_AMOUNT; //for cases whereby there is no need for compensationDisputed, this amount is purely just for voters
const VOTER_DEPOSIT_AMOUNT = 100000000000000; //Whenever a voter vote, must deposit this amount
const MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes
const MIN_VOTES_REQUIRED = 20;

contract("RideHailingDispute", (accounts) => {
  const passengerAccount = accounts[0];
  const passengerAccount1 = accounts[2];
  const passengerAccount2 = accounts[3];
  const passengerAccount3 = accounts[4];
  const driverAccount = accounts[1];

  before(async () => {
    appInstance = await RideHailingApp.deployed();
    accountsContractAddress = await appInstance.accountsContract();
    accountsInstance = await RideHailingAccountManagement.at(accountsContractAddress);
    passengerContractAddress = await appInstance.passengerContract();
    passengerContractInstance = await RideHailingPassenger.at(passengerContractAddress);
    driverContractAddress = await appInstance.driverContract();
    driverContractInstance = await RideHailingDriver.at(driverContractAddress);
    disputeContractAddress = await appInstance.disputesContract();
    disputeContractInstance = await RideHailingDispute.at(disputeContractAddress);
  });

  console.log("Testing Dispute Contract");

  it("Creation of accounts", async () => {
    await accountsInstance.createAccount("passenger1", {
      from: passengerAccount1,
      value: oneEth.dividedBy(10),
    });
    await accountsInstance.createAccount("passenger2", {
      from: passengerAccount2,
      value: oneEth.dividedBy(10),
    });
    await accountsInstance.createAccount("passenger3", {
      from: passengerAccount3,
      value: oneEth.dividedBy(10),
    });
  });

  it("should allow driver to accept a ride successfully", async () => {
    await accountsInstance.createAccount("passenger", {
      from: passengerAccount,
      value: oneEth.dividedBy(10),
    });

    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"), //ride id is 1
    });

    await driverContractInstance.acceptRideRequest(1, {
      from: driverAccount,
    });
    const driver = await driverContractInstance.getDriver(1);
    await assert.strictEqual(driver, driverAccount, "Driver not set to driverContract");
  });

  it("Should be able to start a dispute", async () => {
    await disputeContractInstance.createDispute(
      driverAccount,
      "Driver crashed, I want a compensation",
      1, // rideId
      false, // rideFareDisputed
      true, // compensationDisputed
      { from: passengerAccount }
    );
    const defendant = await disputeContractInstance.getDefendant(0); //disputeId
    await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");
  });

  it("New accounts cannot vote for a dispute due to lack of ratings", async () => {
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 1, { from: passengerAccount1 })
    );
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 2, { from: passengerAccount2 })
    );
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 1, { from: passengerAccount3 })
    );
  });

  it("Defendant should be able to give in to a dispute", async () => {
    await disputeContractInstance.giveInDispute(0, { from: driverAccount });
  });

  it("Check if dispute is resolved", async () => {
    const solved = await disputeContractInstance.checkDisputeSolved(0);
    await assert.strictEqual(true, solved, "Dispute is still not solved!");
  });

  it("should allow driver to accept a 2nd ride successfully", async () => {
    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    });

    await driverContractInstance.acceptRideRequest(2, {
      //ride id is 2
      from: driverAccount,
    });
    const driver = await driverContractInstance.getDriver(2);
    await assert.strictEqual(driver, driverAccount, "Driver not set to driverContract");
  });

  // it("Should be able to start a 2nd dispute", async() => {
  //   await disputeLibraryContractInstance.createDispute(driverAccount, "Driver crashed, I want car fee refund", 2, true, false, {from: passengerAccount});
  //   const defendant = await disputeContractInstance.getDefendant(1); //dispute id is 1
  //   await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");
  // });

  // it("Defendant should be able to respond to the dispute", async() => {
  //   await disputeLibraryContractInstance.respondDispute(1, "I did not crash", {from:driverAccount});
  //   const responded = await disputeContractInstance.getDisputeReponded(1);
  //   await assert.strictEqual(responded, true, "Dispute has not been responded!");
  // })

  //   it("Should not be able to vote for yourself", async () => {
  //     await truffleAssert.reverts(
  //       disputeContractInstance.voteDispute(1, 1, { from: passengerAccount })
  //     );
  //     await truffleAssert.reverts(disputeContractInstance.voteDispute(1, 1, { from: driverAccount }));
  //   });

  //   it("Should be able to vote for dispute", async () => {
  //     await accountsInstance.rateUser(10, passengerAccount1, { from: passengerAccount2 });
  //     await accountsInstance.rateUser(10, passengerAccount2, { from: passengerAccount2 });
  //     await accountsInstance.rateUser(10, passengerAccount3, { from: passengerAccount2 });
  //     await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount1 });
  //     await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount2 });
  //     await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount3 });
  //     let balance = new BigNumber(
  //       await accountsInstance.getAccountBalance({ from: passengerAccount1 })
  //     );
  //     console.log(balance);
  //     console.log(oneEth.dividedBy(10).minus(new BigNumber(VOTER_DEPOSIT_AMOUNT)));
  //     await assert.strictEqual(
  //       balance.isEqualTo(oneEth.dividedBy(10).minus(new BigNumber(VOTER_DEPOSIT_AMOUNT))),
  //       true,
  //       "Voted amount is different"
  //     );
  //   });

  //   it("Ending dispute before reaching minimum", async () => {
  //     await disputeContractInstance.endVote(1);
  //     let balance = new BigNumber(
  //       await accountsInstance.getAccountBalance({ from: passengerAccount1 })
  //     );
  //     await assert.strictEqual(
  //       balance.isEqualTo(oneEth.dividedBy(10)),
  //       true,
  //       "Voted amount is different"
  //     );
  //   });

  //   it("Should allow driver to accept a 3rd ride successfully", async () => {
  //     const bidAmount = web3.utils.toWei("1", "ether");
  //     const startLocation = "ABC Street";
  //     const destination = "XYZ Street";
  //     await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
  //       from: passengerAccount,
  //       value: web3.utils.toWei("1", "ether"),
  //     });

  //     await driverContractInstance.acceptRideRequest(3, {
  //       //ride id is 3
  //       from: driverAccount,
  //     });
  //     const driver = await driverContractInstance.getDriver(3);
  //     await assert.strictEqual(driver, driverAccount, "Driver not set to driverContract");
  //   });

  //   // it("Should be able to start a 3rd dispute", async() => {
  //   //   await disputeLibraryContractInstance.createDispute(driverAccount, "Driver crashed, I want car fee refund", 3, true, true, {from: passengerAccount});
  //   //   const defendant = await disputeContractInstance.getDefendant(2); //dispute id is 2
  //   //   await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");
  //   // });

  //   // it("Defendant should be able to respond to the 3rd dispute", async() => {
  //   //   await disputeLibraryContractInstance.respondDispute(2, "I did not crash", {from:driverAccount});
  //   //   const responded = await disputeContractInstance.getDisputeReponded(2);
  //   //   await assert.strictEqual(responded, true, "Dispute has not been responded!");
  //   // });

  //   it("Creation of additonal accounts", async () => {});

  //   it("Should auto end vote when hit max votes", async () => {
  //     await disputeContractInstance.voteDispute(2, 1, { from: passengerAccount1 });
  //     await disputeContractInstance.voteDispute(2, 1, { from: passengerAccount2 });
  //     await disputeContractInstance.voteDispute(2, 1, { from: passengerAccount3 });
  //   });

  //   it("Should not vote for a dispute that does not exist", async () => {
  //     await truffleAssert.reverts(
  //       disputeLibraryContractInstance.voteDisputeTest(10, 1, { from: passengerAccount2 })
  //     );
  //   });

  //   it("Test end vote", async () => {
  //     await disputeContractInstance.endVote(2);
  //   });
});

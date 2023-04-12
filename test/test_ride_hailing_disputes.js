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

    await accountsInstance.createAccount("passenger", {
      from: passengerAccount,
      value: oneEth.dividedBy(10),
    });
    await accountsInstance.createAccount("passenger1", {
      from: passengerAccount1,
      value: oneEth.dividedBy(10),
    });
    await accountsInstance.createAccount("driver", {
      from: driverAccount,
      value: oneEth.dividedBy(10),
    });

    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    });
    await driverContractInstance.acceptRideRequest(1, {
      //ride id is 1
      from: driverAccount,
    });
  });

  console.log("Testing Dispute Contract");

  it("No open disputes initially", async () => {
    const openDisputes = await disputeContractInstance.getOpenDisputes();
    assert.strictEqual(openDisputes.length, 0);
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
    const defendant = await disputeContractInstance.getDefendant(0); // disputeId
    await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");
    const openDisputes = await disputeContractInstance.getOpenDisputes();
    assert.strictEqual(openDisputes.length, 1);
    assert.strictEqual(openDisputes[0].toNumber(), 0);
  });

  // todo cannot create dispute for ride not involving plantiff and defendant

  it("Cannot vote for own dispute", async () => {
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 1, { from: passengerAccount }),
      "You cannot vote for yourself!"
    );
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 1, { from: driverAccount }),
      "You cannot vote for yourself!"
    );
  });

  it("New accounts cannot vote for a dispute due to lack of ratings", async () => {
    await truffleAssert.reverts(
      disputeContractInstance.voteDispute(0, 1, { from: passengerAccount1 }),
      "You need a minimum overall rating of 3 to vote"
    );
  });

  // TODO another test for passenger cannot request rides without responding too
  it("Driver cannot accept rides without responding to open disputes to which they are defendant", async () => {
    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    }); //ride id is 2

    await truffleAssert.reverts(
      driverContractInstance.acceptRideRequest(2, {
        from: driverAccount,
      }),
      "You have yet to respond your disputes"
    );
  });

  it("Defendant should be able to give in to a dispute", async () => {
    await disputeContractInstance.giveInDispute(0, { from: driverAccount });
    assert(await disputeContractInstance.isDisputeResolved(0));
  });

  it("Driver can accept new ride after responding to dispute", async () => {
    await driverContractInstance.acceptRideRequest(2, {
      from: driverAccount,
    });
    const driver = await driverContractInstance.getDriver(2);
    await assert.strictEqual(driver, driverAccount, "Driver not set to driverContract");
  });

  it("Defendant can respond by challenging dispute", async () => {
    await disputeContractInstance.createDispute(
      driverAccount,
      "Driver crashed, I want ride fee refund",
      2,
      true,
      false,
      { from: passengerAccount }
    );
    const defendant = await disputeContractInstance.getDefendant(1); //dispute id is 1
    await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");

    await disputeContractInstance.challengeDispute(1, "I did not crash", {
      from: driverAccount,
    });
    await assert(await disputeContractInstance.isDisputeResponded(1));
  });

  // it("Should be able to vote for dispute", async () => {
  //   await accountsInstance.rateUser(10, passengerAccount1, { from: passengerAccount2 });
  //   await accountsInstance.rateUser(10, passengerAccount2, { from: passengerAccount2 });
  //   await accountsInstance.rateUser(10, passengerAccount3, { from: passengerAccount2 });
  //   await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount1 });
  //   await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount2 });
  //   await disputeContractInstance.voteDispute(1, 1, { from: passengerAccount3 });
  //   let balance = new BigNumber(
  //     await accountsInstance.getAccountBalance({ from: passengerAccount1 })
  //   );
  //   console.log(balance);
  //   console.log(oneEth.dividedBy(10).minus(new BigNumber(VOTER_DEPOSIT_AMOUNT)));
  //   await assert.strictEqual(
  //     balance.isEqualTo(oneEth.dividedBy(10).minus(new BigNumber(VOTER_DEPOSIT_AMOUNT))),
  //     true,
  //     "Voted amount is different"
  //   );
  // });

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

  // it("Should be able to start a 3rd dispute", async() => {
  //   await disputeLibraryContractInstance.createDispute(driverAccount, "Driver crashed, I want car fee refund", 3, true, true, {from: passengerAccount});
  //   const defendant = await disputeContractInstance.getDefendant(2); //dispute id is 2
  //   await assert.strictEqual(defendant, driverAccount, "Defendant does not match!");
  // });

  // it("Defendant should be able to respond to the 3rd dispute", async() => {
  //   await disputeLibraryContractInstance.respondDispute(2, "I did not crash", {from:driverAccount});
  //   const responded = await disputeContractInstance.getDisputeReponded(2);
  //   await assert.strictEqual(responded, true, "Dispute has not been responded!");
  // });

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

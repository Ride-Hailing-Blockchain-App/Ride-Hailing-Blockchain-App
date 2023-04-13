// SPDX-License-Identifier: MIT

const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
const assert = require("assert");
const { start } = require("repl");

const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccountManagement = artifacts.require("RideHailingAccountManagement");
const RideHailingPassenger = artifacts.require("RideHailingPassenger");
const RideHailingDriver = artifacts.require("RideHailingDriver");
const RideHailingDispute = artifacts.require("RideDispute");

const oneEth = new BigNumber(1000000000000000000);
const MIN_DISPUTE_AMOUNT = 2000000000000000; //compensationDisputed amount + dispute deposit
const TRANSFER_AMOUNT = 500000000000000; // aka compensationDisputed amount, included in the MIN_DISPUTE_AMOUNT
const NONCOMPENSATION_AMOUNT = MIN_DISPUTE_AMOUNT - TRANSFER_AMOUNT; //for cases whereby there is no need for compensationDisputed, this amount is purely just for voters
const VOTER_DEPOSIT_AMOUNT = 100000000000000; //Whenever a voter vote, must deposit this amount
const MAX_VOTES = 50; //One disputes can only have a max of 50 votes before it automatically closes
const MIN_VOTES_REQUIRED = 20;

contract("RideHailingDispute", (accounts) => {
  const passengerAccount = accounts[0];
  const driverAccount = accounts[1];
  const passengerAccount1 = accounts[2];
  const passengerAccount2 = accounts[3];
  const passengerAccount3 = accounts[4];

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

  it("Should not be able to start a dispute that the ride does not belong to plantiff and defendant", async () => {
    await truffleAssert.reverts(
      disputeContractInstance.createDispute(
        driverAccount,
        "Driver crashed, I was a compensation",
        1, // ride id
        false, // rideFareDisputed
        true, // compensationDisputed
        { from: accounts[5] }
      )
    );
    await truffleAssert.reverts(
      disputeContractInstance.createDispute(
        accounts[5],
        "Driver crashed, I was a compensation",
        1, // ride id
        false, // rideFareDisputed
        true, // compensationDisputed
        { from: driverAccount }
      )
    );
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

  it("Vote ends with plantiff win", async () => {
    for (let i = 5; i < 45; i++) {
      await accountsInstance.createAccount("voter" + i.toString(), {
        from: accounts[i],
        value: oneEth.dividedBy(10),
      });
      await accountsInstance.rateUser(10, accounts[i], { from: passengerAccount2 });
      await disputeContractInstance.voteDispute(1, 1, { from: accounts[i] });
    }
    let balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isEqualTo(
        oneEth
          .dividedBy(10)
          .minus(new BigNumber(await disputeContractInstance.VOTER_DEPOSIT_AMOUNT()))
      ),
      "Voter deposit should be deducted"
    );

    for (let i = 45; i < 55; i++) {
      await accountsInstance.createAccount("voter" + i.toString(), {
        from: accounts[i],
        value: oneEth.dividedBy(10),
      });
      await accountsInstance.rateUser(10, accounts[i], { from: passengerAccount2 });
      await disputeContractInstance.voteDispute(1, 2, { from: accounts[i] });
    }
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isGreaterThan(oneEth.dividedBy(10)),
      "Winning voter deposit should be returned + winnings"
    );
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[45] }));
    await assert(
      balance.isEqualTo(
        oneEth
          .dividedBy(10)
          .minus(new BigNumber(await disputeContractInstance.VOTER_DEPOSIT_AMOUNT()))
      ),
      "Losing voter deposit should be deducted"
    );
  });

  it("Passenger cannot request for another ride without responding to open disputes to which they are defendant", async () => {
    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";
    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    }); //ride id is 3

    await driverContractInstance.acceptRideRequest(3, { from: driverAccount });

    await disputeContractInstance.createDispute(
      passengerAccount,
      "Passenger is late, I want comepensation",
      3,
      false,
      true,
      { from: driverAccount }
    );
    await truffleAssert.reverts(
      passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
        from: passengerAccount,
        value: web3.utils.toWei("1", "ether"),
      }),
      "You have yet to respond your disputes"
    );
  });

  it("Passenger can request for new ride after responding to dispute", async () => {
    const bidAmount = web3.utils.toWei("1", "ether");
    const startLocation = "ABC Street";
    const destination = "XYZ Street";

    await disputeContractInstance.challengeDispute(2, "I am not late", {
      from: passengerAccount,
    });

    await assert(await disputeContractInstance.isDisputeResponded(2));

    await passengerContractInstance.requestRide(bidAmount, startLocation, destination, {
      from: passengerAccount,
      value: web3.utils.toWei("1", "ether"),
    }); //ride id is 4
  });

  it("Vote ends with defendant winning", async () => {
    let initialBalanceAccount5 = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[5] })
    );
    for (let i = 5; i < 45; i++) {
      await disputeContractInstance.voteDispute(2, 2, { from: accounts[i] });
    }
    let balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isEqualTo(
        initialBalanceAccount5.minus(
          new BigNumber(await disputeContractInstance.VOTER_DEPOSIT_AMOUNT())
        )
      ),
      "Voter deposit should be deducted"
    );
    initialBalance = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[45] })
    );
    for (let i = 45; i < 55; i++) {
      await disputeContractInstance.voteDispute(2, 1, { from: accounts[i] });
    }
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[45] }));
    await assert(
      balance.isEqualTo(
        initialBalance.minus(new BigNumber(await disputeContractInstance.VOTER_DEPOSIT_AMOUNT()))
      ),
      "Losing voter deposit should be deducted"
    );
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isGreaterThan(initialBalanceAccount5),
      "Winning voter deposit should be returned + winnings"
    );
  });

  it("Dispute has indeterminate outcome", async () => {
    await driverContractInstance.acceptRideRequest(4, { from: driverAccount });
    await disputeContractInstance.createDispute(
      driverAccount,
      "Driver is late, I want comepensation",
      4,
      false,
      true,
      { from: passengerAccount }
    );
    await disputeContractInstance.challengeDispute(3, "I am not late", {
      from: driverAccount,
    });
    await assert(await disputeContractInstance.isDisputeResponded(3));

    let initialBalanceAccount5 = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[5] })
    );
    for (let i = 5; i < 30; i++) {
      await disputeContractInstance.voteDispute(3, 2, { from: accounts[i] });
    }
    let balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isEqualTo(
        initialBalanceAccount5.minus(
          new BigNumber(await disputeContractInstance.VOTER_DEPOSIT_AMOUNT())
        )
      ),
      "Voter deposit should be deducted"
    );
    initialBalanceAccount45 = new BigNumber(
      await accountsInstance.getAccountBalance({ from: accounts[45] })
    );
    for (let i = 30; i < 55; i++) {
      await disputeContractInstance.voteDispute(3, 1, { from: accounts[i] });
    }
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[45] }));
    await assert(
      balance.isEqualTo(initialBalanceAccount45),
      "Voter deposit should be returned due to indeterminate outcome"
    );
    balance = new BigNumber(await accountsInstance.getAccountBalance({ from: accounts[5] }));
    await assert(
      balance.isEqualTo(initialBalanceAccount5),
      "Voter deposit should be returned due to indeterminate outcome"
    );
  });
});

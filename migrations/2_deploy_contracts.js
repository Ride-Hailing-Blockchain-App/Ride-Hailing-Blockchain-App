const RideHailingApp = artifacts.require("RideHailingApp");
const RideHailingAccounts = artifacts.require("RideHailingAccounts");

module.exports = (deployer, network, accounts) => {
  deployer
    .deploy(RideHailingAccounts)
    .then(function () {
      return deployer.deploy(RideHailingApp, RideHailingAccounts.address);
    })
};

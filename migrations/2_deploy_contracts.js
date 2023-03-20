const RideHailingApp = artifacts.require("RideHailingApp");

module.exports = (deployer, network, accounts) => {
  deployer.deploy(RideHailingApp);
};

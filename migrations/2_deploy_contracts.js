const DummyOracle = artifacts.require("../contracts/oracles/DummyOracle")
const RideHailingApp = artifacts.require("RideHailingApp");

module.exports = (deployer, network, accounts) => {
    deployer.deploy(DummyOracle).then(function(){
        return deployer.deploy(RideHailingApp, DummyOracle.address);
    });
};

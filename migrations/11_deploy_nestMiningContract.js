const Nest_3_MiningContract = artifacts.require("Nest_3_MiningContract");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_MiningContract, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.miningSave', Nest_3_MiningContract.address));
  })
};

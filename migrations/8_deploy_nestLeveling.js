const Nest_3_Leveling = artifacts.require("Nest_3_Leveling");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_Leveling, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.leveling', Nest_3_Leveling.address));
  })
};

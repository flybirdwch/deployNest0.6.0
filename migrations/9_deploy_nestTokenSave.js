const Nest_3_TokenSave = artifacts.require("Nest_3_TokenSave");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_TokenSave, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.tokenSave', Nest_3_TokenSave.address));
  })
};

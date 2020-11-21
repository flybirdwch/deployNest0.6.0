const Nest_3_TokenAbonus = artifacts.require("Nest_3_TokenAbonus");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_TokenAbonus, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.tokenAbonus', Nest_3_TokenAbonus.address));
  })
};

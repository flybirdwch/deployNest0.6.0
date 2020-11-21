const Nest_NToken_TokenMapping = artifacts.require("Nest_NToken_TokenMapping");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_NToken_TokenMapping, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.nToken.tokenMapping', Nest_NToken_TokenMapping.address));
  })
};

const Nest_NToken_TokenAuction = artifacts.require("Nest_NToken_TokenAuction");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_NToken_TokenAuction, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.nToken.tokenAuction', Nest_NToken_TokenAuction.address));
  })
};

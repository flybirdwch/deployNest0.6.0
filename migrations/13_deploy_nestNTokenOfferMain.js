const Nest_NToken_OfferMain = artifacts.require("Nest_NToken_OfferMain");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_NToken_OfferMain, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.nToken.offerMain', Nest_NToken_OfferMain.address));
  })
};

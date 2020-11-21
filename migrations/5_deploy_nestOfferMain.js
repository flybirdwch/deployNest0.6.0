const Nest_3_OfferMain = artifacts.require("Nest_3_OfferMain");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_OfferMain, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.offerMain', Nest_3_OfferMain.address));
  })
};

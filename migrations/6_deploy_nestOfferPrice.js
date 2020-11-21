const Nest_3_OfferPrice = artifacts.require("Nest_3_OfferPrice");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_3_OfferPrice, Nest_3_VoteFactory.address).then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.Nest_3_OfferPrice', Nest_3_OfferPrice.address));
  })
};

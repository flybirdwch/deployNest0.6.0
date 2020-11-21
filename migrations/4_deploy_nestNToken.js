const Nest_NToken = artifacts.require("Nest_NToken");
const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  deployer.deploy(Nest_NToken, 'NestNode', 'NN', Nest_3_VoteFactory.address, '0x3c385Cd0eE6fc17f49c4Bc900B8652c402704b38').then(function() {
    Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nestNode', Nest_NToken.address));
    return Nest_3_VoteFactory.deployed().then(instance => instance.checkAddress('nestNode'));
  })
};

const Nest_3_VoteFactory = artifacts.require("Nest_3_VoteFactory");

module.exports = function (deployer) {
  Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest', '0xA9481F2C1f0fdc58fB8d1884e3F05f12CD5C2355'));//Nest Token deployed in 0.5.0 solc
  Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.coder', '0x3c385Cd0eE6fc17f49c4Bc900B8652c402704b38'));
  Nest_3_VoteFactory.deployed().then(instance => instance.addContractAddress('nest.v3.destruction', '0xc87758d6CD4531f41827C07691483b6e2ED7560e'));
};
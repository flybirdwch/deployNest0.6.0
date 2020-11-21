require('dotenv').config();
const Web3 = require("web3");
const web3 = new Web3();
const WalletProvider = require("truffle-wallet-provider");
const Wallet = require('ethereumjs-wallet');

var ropstenPrivateKey = new Buffer(process.env["ROPSTEN_PRIVATE_KEY"], "hex");
var ropstenWallet = Wallet.default.fromPrivateKey(ropstenPrivateKey);
var ropstenProvider = new WalletProvider(ropstenWallet, "https://ropsten.infura.io/v3/de704c06208c45ebb5685e2bc77cae37");
module.exports = {
  networks: {
    dev: { // Whatever network our local node connects to
        network_id: "*", // Match any network id
        host: "localhost",
        port: 8545,
      },
      ropsten: { // Provided by Infura, load keys in .env file
        network_id: "3",
        provider: ropstenProvider,
      }
    },
  solc: {
      optimizer: {
        enabled: true,
        runs: 200
      }
  },
  compilers: {
    solc: {
      version: "0.6.0",
    }
  }
};

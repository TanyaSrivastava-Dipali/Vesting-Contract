require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-prettier");

const Private_Key =
  "Your wallet private key";

module.exports = {
  solidity: "0.8.10",
  networks: {
    rinkeby: {
      url: `your infura link`,
      accounts: [`0x${Private_Key}`],
    },
  },
  etherscan: {
    apiKey: "your etherscan api key",
  },
};

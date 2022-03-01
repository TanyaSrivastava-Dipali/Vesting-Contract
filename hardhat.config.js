require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-prettier");

const Private_Key =
  "f3207435874fc6fa7df191e3d9adffc435cf29ed28e8f80beb677c5b91bb611f";

module.exports = {
  solidity: "0.8.10",
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/5a8ba29c44b840b4b5b315cf958266ae`,
      accounts: [`0x${Private_Key}`],
    },
  },
  etherscan: {
    apiKey: "QDEAN63NZR4KGQSFFG3DHSU5UE2B5SEEVV",
  },
};

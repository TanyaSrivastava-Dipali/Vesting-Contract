const hre = require("hardhat");

async function main() {
  const ERC = await hre.ethers.getContractFactory("MyToken");
  const erc = await ERC.deploy(10000000000);

  await erc.deployed();

  console.log("erc deployed to:", erc.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

//0x96D5126b5B3013b421f915c135c41fe0B3183085
//0x7CaB1B62C01624417375994E2836EC23D2b005Ef
//0xeb480F192d25BD5976C96DdFfEf2E2Ed32bfFd71
//npx hardhat run scripts/ERC20.js --network rinkeby
//npx hardhat verify --contract "contracts/erc20.sol:MyToken"  --network rinkeby  0xeb480F192d25BD5976C96DdFfEf2E2Ed32bfFd71 10000000000
//verified link      https://rinkeby.etherscan.io/address/0x96D5126b5B3013b421f915c135c41fe0B3183085#code

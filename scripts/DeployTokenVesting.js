const hre = require("hardhat");

async function main() {
  const Vesting = await hre.ethers.getContractFactory("TokenVesting");
  const vesting = await Vesting.deploy(
    "0x96D5126b5B3013b421f915c135c41fe0B3183085"
  );

  await vesting.deployed();

  console.log("Contract deployed to:", vesting.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

//0x3084196906Ae307AaC9ED3aA47A68Aea9420c185
//0xDF46Ff00656F74E635e7b544DFF81B1cB5DFA241
//https://rinkeby.etherscan.io/address/0x3084196906Ae307AaC9ED3aA47A68Aea9420c185#code

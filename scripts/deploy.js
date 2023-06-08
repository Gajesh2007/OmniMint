// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  // Optimism
  const Destination = await hre.ethers.getContractFactory("NFTMint");
  const destination = await Destination.deploy(
    "",
    "OmniMint",
    "oMint",
    true,
    // random weth i found on optimism explorer
    "0x494396f42ec90e4eb815d8fbbb3b5fdf016970b2"
  );

  await destination.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
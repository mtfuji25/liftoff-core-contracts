// undoIgniteEth, claimRefundEth, launchTokenWithFixedRate added into the liftoffEngine

const { ethers, upgrades } = require("hardhat");
const loadJsonFile = require('load-json-file');
const addresses = loadJsonFile.sync("./scripts/addresses.json").networks.ropsten;

async function main() {
  //Silences "struct" warnings
  //WARNING: do NOT add new properties, structs, mappings etc to these contracts in upgrades.
  upgrades.silenceWarnings()

  // We get the contract to deploy
  const LiftoffEngine = await ethers.getContractFactory("LiftoffEngine");

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.LiftoffEngine, LiftoffEngine, {unsafeAllowCustomTypes: true});

  console.log("Script complete.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
const { BigNumber } = require("ethers");
const { ethers, upgrades } = require("hardhat");
const loadJsonFile = require('load-json-file');
const addresses = loadJsonFile.sync("./scripts/addresses.json").networks.ropsten;
const settings = loadJsonFile.sync("./scripts/settings.json").networks.ropsten;

async function main() {
  //Silences "struct" warnings
  //WARNING: do NOT add new properties, structs, mappings etc to these contracts in upgrades.
  upgrades.silenceWarnings()

  // We get the contract to deploy
  const LiftoffEngine = await ethers.getContractFactory("LiftoffEngine");
  const LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance");

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.LiftoffEngine, LiftoffEngine, {unsafeAllowCustomTypes: true});
  console.log("Upgrading liftoff insurance...");
  const liftoffInsurance = await upgrades.upgradeProxy(addresses.LiftoffInsurance, LiftoffInsurance, {unsafeAllowCustomTypes: true});

  console.log("Script complete.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
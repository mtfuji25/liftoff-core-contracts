const { BigNumber } = require("ethers");
const { ethers, upgrades } = require("hardhat");
const loadJsonFile = require('load-json-file');
const addresses = loadJsonFile.sync("./scripts/settings.json").networks.ropsten;

async function main() {
  //Silences "struct" warnings
  //WARNING: do NOT add new properties, structs, mappings etc to these contracts in upgrades.
  upgrades.silenceWarnings()

  // We get the contract to deploy
  const LiftoffSettings = await ethers.getContractFactory("LiftoffSettings")
  const LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance")
  const LiftoffEngine = await ethers.getContractFactory("LiftoffEngine")
  const LiftoffPartnerships = await ethers.getContractFactory("LiftoffPartnerships")

  console.log("Deploying liftoff partnerships...");
  const liftoffPartnerships = await upgrades.deployProxy(LiftoffPartnerships, [addresses.liftoffSettings], {unsafeAllowCustomTypes: true});
  await liftoffPartnerships.deployed();
  console.log("LiftoffPartnerships deployed to:", liftoffPartnerships.address);

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.liftoffEngine, LiftoffEngine);
  console.log("Upgrading liftoff setings...");
  const liftoffSettings = await upgrades.upgradeProxy(addresses.liftoffSettings, LiftoffSettings);
  console.log("Upgrading liftoff insurance...");
  const liftoffInsurance = await upgrades.upgradeProxy(addresses.liftoffInsurance, LiftoffInsurance);
  console.log("Upgrades complete.");

  console.log("Calling setLiftoffPartnerships...");
  liftoffSettings.setLiftoffPartnerships(liftoffPartnerships.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
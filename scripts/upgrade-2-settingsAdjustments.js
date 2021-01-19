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
  const LiftoffPartnerships = await ethers.getContractFactory("LiftoffPartnerships");

  const liftoffRegistration = await ethers.getContractAt("LiftoffRegistration",addresses.LiftoffRegistration);
  const liftoffSettings = await ethers.getContractAt("LiftoffSettings",addresses.LiftoffSettings);

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.LiftoffEngine, LiftoffEngine, {unsafeAllowCustomTypes: true});
  console.log("Upgrading liftoff partnerships...");
  const liftoffPartnerships = await upgrades.upgradeProxy(addresses.LiftoffPartnerships, LiftoffPartnerships, {unsafeAllowCustomTypes: true});
  console.log("Upgrades complete.");

  console.log("Setting LiftoffSettings uints...");
  await liftoffSettings.setAllUints(
    settings.ethXLockBP,
    settings.tokenUserBP,
    settings.insurancePeriod,
    settings.baseFeeBP,
    settings.ethBuyBP,
    settings.projectDevBP,
    settings.mainFeeBP,
    settings.lidPoolBP
  );
  
  console.log("Setting LiftoffRegistration softCapTimer...");
  await liftoffRegistration.setSoftCapTimer(
    settings.softCapTimer
  );

  console.log("Updating current presale endtimes:");
  console.log("Updating 4...");
  await liftoffEngine.updateEndTime(
    settings.softCapTimer,
    4
  );
  console.log("Updating 6...");
  await liftoffEngine.updateEndTime(
    settings.softCapTimer,
    6
  );
  console.log("Script complete.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
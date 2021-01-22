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

  const liftoffSettings = await ethers.getContractAt("LiftoffSettings",addresses.LiftoffSettings);
  const liftoffRegistration = await ethers.getContractAt("LiftoffRegistration",addresses.LiftoffRegistration);

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.LiftoffEngine, LiftoffEngine, {unsafeAllowCustomTypes: true});
  console.log("Upgrading liftoff insurance...");
  const liftoffInsurance = await upgrades.upgradeProxy(addresses.LiftoffInsurance, LiftoffInsurance, {unsafeAllowCustomTypes: true});

  console.log("liftoffSettings: Calling setLiftoffEngine...");
  await liftoffSettings.setLiftoffEngine(
    liftoffEngine.address
  );
  console.log("liftoffSettings: Calling setLiftoffInsurance...");
  await liftoffSettings.setLiftoffInsurance(
    liftoffInsurance.address
  );
  console.log("liftoffRegistration: Calling setLiftoffEngine...");
  await liftoffRegistration.setLiftoffEngine(
    liftoffEngine.address
  );

  console.log("Script complete.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
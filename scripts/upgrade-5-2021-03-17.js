// fix double claim issue in liftoffInsurance
// introduced bonusInsurance feature in liftoffInsurance
// add airdrop feature in liftoffSettings and liftoffInsurance
// fix totalSupply calculation in liftoffEngine

const { ethers, upgrades } = require("hardhat");
const loadJsonFile = require('load-json-file');
const addresses = loadJsonFile.sync("./scripts/addresses.json").networks.ropsten;

async function main() {
  //Silences "struct" warnings
  //WARNING: do NOT add new properties, structs, mappings etc to these contracts in upgrades.
  upgrades.silenceWarnings()

  // We get the contract to deploy
  const LiftoffSettings = await ethers.getContractFactory("LiftoffSettings")
  const LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance")
  const LiftoffEngine = await ethers.getContractFactory("LiftoffEngine");

  console.log("Upgrading liftoff engine...");
  const liftoffEngine = await upgrades.upgradeProxy(addresses.LiftoffEngine, LiftoffEngine, {unsafeAllowCustomTypes: true});
  console.log("Upgrading liftoff setings...");
  const liftoffSettings = await upgrades.upgradeProxy(addresses.LiftoffSettings, LiftoffSettings);
  console.log("Upgrading liftoff insurance...");
  const liftoffInsurance = await upgrades.upgradeProxy(addresses.LiftoffInsurance, LiftoffInsurance, {unsafeAllowCustomTypes: true});
  console.log("Upgrades complete.");

  console.log("Setting AirdropBP...");
  await liftoffSettings.setAirdropBP(settings.airdropBP);
  console.log("Setting AirdropDistributor...");
  await liftoffSettings.setAirdropDistributor(settings.airdropDistributor);

  console.log("Script complete.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
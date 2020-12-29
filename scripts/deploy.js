const { BigNumber } = require("ethers")
const { ethers, upgrades } = require("hardhat")
const loadJsonFile = require('load-json-file')
const settings = loadJsonFile.sync("./scripts/settings.json").networks.ropsten


async function main() {

    //Silences "struct" warnings
    //WARNING: do NOT add new properties, structs, mappings etc to these contracts in upgrades.
    upgrades.silenceWarnings()

    // We get the contract to deploy
    const LiftoffSettings = await ethers.getContractFactory("LiftoffSettings")
    const LiftoffEngine = await ethers.getContractFactory("LiftoffEngine")
    const LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance")
    const LiftoffRegistration = await ethers.getContractFactory("LiftoffRegistration")

    console.log("Starting deployments...")

    const liftoffSettings = await upgrades.deployProxy(LiftoffSettings, [], {unsafeAllowCustomTypes: true})
    await liftoffSettings.deployed()
    console.log("liftoffEngine deployed to:", liftoffSettings.address)

    const liftoffEngine = await upgrades.deployProxy(LiftoffEngine, [liftoffSettings.address], {unsafeAllowCustomTypes: true})
    await liftoffEngine.deployed()
    console.log("liftoffEngine deployed to:", liftoffEngine.address)

    const liftoffInsurance = await upgrades.deployProxy(LiftoffInsurance, [liftoffSettings.address], {unsafeAllowCustomTypes: true})
    await liftoffInsurance.deployed()
    console.log("liftoffEngine deployed to:", liftoffInsurance.address)

    const liftoffRegistration = await upgrades.deployProxy(LiftoffRegistration, [
        settings.minTimeToLaunch,
        settings.maxTimeToLaunch,
        settings.softCapTimer,
        liftoffEngine.address
      ], {unsafeAllowCustomTypes: true})
    await liftoffRegistration.deployed()
    console.log("liftoffEngine deployed to:", liftoffRegistration.address)

    console.log("setting uints")
    await liftoffSettings.setAllUints(
      settings.ethXLockBP,
      settings.tokenUserBP,
      settings.insurancePeriod,
      settings.baseFeeBP,
      settings.ethBuyBP,
      settings.projectDevBP,
      settings.mainFeeBP,
      settings.lidPoolBP
    )

    console.log("setting addresses")
    await liftoffSettings.setAllAddresses(
      liftoffInsurance.address,
      liftoffRegistration.address,
      liftoffEngine.address,
      settings.xEth,
      settings.xLocker,
      settings.uniswapRouter,
      settings.lidTreasury,
      settings.lidPoolManager
    )
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  
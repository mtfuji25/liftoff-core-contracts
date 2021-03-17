const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { time } = require("@openzeppelin/test-helpers");

chai.use(solidity);

describe('LiftoffSettings', function () {
  let liftoffSettings;

  before(async function () {
    LiftoffSettings = await ethers.getContractFactory("LiftoffSettings");
    liftoffSettings = await upgrades.deployProxy(LiftoffSettings, []);
    await liftoffSettings.deployed();
  });

  it('setAllUints', async function () {
    await liftoffSettings.setAllUints(
      1200,
      5941,
      time.duration.days(7).toNumber(),
      200,
      3300,
      3500,
      650,
      2350,
      300
    );
    expect(await liftoffSettings.getEthXLockBP()).to.equal(1200);
    expect(await liftoffSettings.getTokenUserBP()).to.equal(5941);
    expect(await liftoffSettings.getInsurancePeriod()).to.equal(time.duration.days(7).toNumber());
    expect(await liftoffSettings.getBaseFeeBP()).to.equal(200);
    expect(await liftoffSettings.getEthBuyBP()).to.equal(3300);
    expect(await liftoffSettings.getProjectDevBP()).to.equal(3500);
    expect(await liftoffSettings.getMainFeeBP()).to.equal(650);
    expect(await liftoffSettings.getLidPoolBP()).to.equal(2350);
    expect(await liftoffSettings.getAirdropBP()).to.equal(300);
  });

  it('setAllAddresses', async function () {
    const [
      liftoffInsurance,
      liftoffRegistration,
      liftoffEngine,
      liftoffPartnerships,
      xEth,
      xLocker,
      uniswapRouter,
      lidTreasury,
      lidPoolManager,
      airdropDistributor
    ] = await ethers.getSigners();
    await liftoffSettings.setAllAddresses(
      liftoffInsurance.address,
      liftoffRegistration.address,
      liftoffEngine.address,
      liftoffPartnerships.address,
      xEth.address,
      xLocker.address,
      uniswapRouter.address,
      lidTreasury.address,
      lidPoolManager.address,
      airdropDistributor.address
    );
    expect(await liftoffSettings.getLiftoffInsurance()).to.equal(liftoffInsurance.address);
    expect(await liftoffSettings.getLiftoffRegistration()).to.equal(liftoffRegistration.address);
    expect(await liftoffSettings.getLiftoffEngine()).to.equal(liftoffEngine.address);
    expect(await liftoffSettings.getLiftoffPartnerships()).to.equal(liftoffPartnerships.address);
    expect(await liftoffSettings.getXEth()).to.equal(xEth.address);
    expect(await liftoffSettings.getXLocker()).to.equal(xLocker.address);
    expect(await liftoffSettings.getUniswapRouter()).to.equal(uniswapRouter.address);
    expect(await liftoffSettings.getLidTreasury()).to.equal(lidTreasury.address);
    expect(await liftoffSettings.getLidPoolManager()).to.equal(lidPoolManager.address);
    expect(await liftoffSettings.getAirdropDistributor()).to.equal(airdropDistributor.address);
  });
 
  it('set/get EthXLockBP', async function () {
    await liftoffSettings.setEthXLockBP(1000);
    expect(await liftoffSettings.getEthXLockBP()).to.equal(1000);
  });

  it('set/get TokenUserBP', async function () {
    await liftoffSettings.setTokenUserBP(1000);
    expect(await liftoffSettings.getTokenUserBP()).to.equal(1000);
  });

  it('set/get AirdropBP', async function () {
    await liftoffSettings.setAirdropBP(300);
    expect(await liftoffSettings.getAirdropBP()).to.equal(300);
  });

  it('set/get LiftoffInsurance', async function () {
    const [liftOffInsurance] = await ethers.getSigners();
    await liftoffSettings.setLiftoffInsurance(liftOffInsurance.address);
    expect(await liftoffSettings.getLiftoffInsurance()).to.equal(liftOffInsurance.address);
  });

  it('set/get LiftOffRegistration', async function () {
    const [liftOffRegistration] = await ethers.getSigners();
    await liftoffSettings.setLiftoffRegistration(liftOffRegistration.address);
    expect(await liftoffSettings.getLiftoffRegistration()).to.equal(liftOffRegistration.address);
  });

  it('set/get LiftoffEngine', async function () {
    const [liftOffEngine] = await ethers.getSigners();
    await liftoffSettings.setLiftoffEngine(liftOffEngine.address);
    expect(await liftoffSettings.getLiftoffEngine()).to.equal(liftOffEngine.address);
  });

  it('set/get LiftoffPartnerships', async function () {
    const [liftoffPartnerships] = await ethers.getSigners();
    await liftoffSettings.setLiftoffPartnerships(liftoffPartnerships.address);
    expect(await liftoffSettings.getLiftoffPartnerships()).to.equal(liftoffPartnerships.address);
  });

  it('set/get XEth', async function () {
    const [xEth] = await ethers.getSigners();
    await liftoffSettings.setXEth(xEth.address);
    expect(await liftoffSettings.getXEth()).to.equal(xEth.address);
  });

  it('set/get XLocker', async function () {
    const [xLocker] = await ethers.getSigners();
    await liftoffSettings.setXLocker(xLocker.address);
    expect(await liftoffSettings.getXLocker()).to.equal(xLocker.address);
  });

  it('set/get UniswapRouter', async function () {
    const [uniswapRouter] = await ethers.getSigners();
    await liftoffSettings.setUniswapRouter(uniswapRouter.address);
    expect(await liftoffSettings.getUniswapRouter()).to.equal(uniswapRouter.address);
  });

  it('set/get InsurancePeriod', async function () {
    await liftoffSettings.setInsurancePeriod(time.duration.days(7).toNumber());
    expect(await liftoffSettings.getInsurancePeriod()).to.equal(time.duration.days(7).toNumber());
  });

  it('set/get LidTreasury', async function () {
    const [lidTreasury] = await ethers.getSigners();
    await liftoffSettings.setLidTreasury(lidTreasury.address);
    expect(await liftoffSettings.getLidTreasury()).to.equal(lidTreasury.address);
  });

  it('set/get LidPoolManager', async function () {
    const [lidPoolManager] = await ethers.getSigners();
    await liftoffSettings.setLidPoolManager(lidPoolManager.address);
    expect(await liftoffSettings.getLidPoolManager()).to.equal(lidPoolManager.address);
  });

  it('set/get AirdropDistributor', async function () {
    const [airdropDistributor] = await ethers.getSigners();
    await liftoffSettings.setAirdropDistributor(airdropDistributor.address);
    expect(await liftoffSettings.getAirdropDistributor()).to.equal(airdropDistributor.address);
  });

  it('setXethBP should revert if sum of BP params is less than 10000', async function () {
    await expect(liftoffSettings.setXethBP(1000, 2000, 3000, 2000, 1000)).to.be.revertedWith("Must allocate 100% of eth raised");
  });

  it('set/get XethBP Params', async function () {
    await liftoffSettings.setXethBP(1000, 2000, 3000, 2000, 2000);
    expect(await liftoffSettings.getBaseFeeBP()).to.equal(1000);
    expect(await liftoffSettings.getEthBuyBP()).to.equal(2000);
    expect(await liftoffSettings.getProjectDevBP()).to.equal(3000);
    expect(await liftoffSettings.getMainFeeBP()).to.equal(2000);
    expect(await liftoffSettings.getLidPoolBP()).to.equal(2000);
  });
});
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
 
  it('set/get EthXLockBP', async function () {
    await liftoffSettings.setEthXLockBP(1000);
    expect(await liftoffSettings.getEthXLockBP()).to.equal(1000);
  });

  it('set/get TokenUserBP', async function () {
    await liftoffSettings.setTokenUserBP(1000);
    expect(await liftoffSettings.getTokenUserBP()).to.equal(1000);
  });

  it('set/get LiftoffInsurance', async function () {
    const [liftOffInsurance] = await ethers.getSigners();
    await liftoffSettings.setLiftoffInsurance(liftOffInsurance.address);
    expect(await liftoffSettings.getLiftoffInsurance()).to.equal(liftOffInsurance.address);
  });

  it('set/get LiftoffLauncher', async function () {
    const [liftOffLauncher] = await ethers.getSigners();
    await liftoffSettings.setLiftoffLauncher(liftOffLauncher.address);
    expect(await liftoffSettings.getLiftoffLauncher()).to.equal(liftOffLauncher.address);
  });

  it('set/get LiftoffEngine', async function () {
    const [liftOffEngine] = await ethers.getSigners();
    await liftoffSettings.setLiftoffEngine(liftOffEngine.address);
    expect(await liftoffSettings.getLiftoffEngine()).to.equal(liftOffEngine.address);
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
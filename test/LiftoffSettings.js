const { expectRevert } = require("@openzeppelin/test-helpers")
const { expect } = require('chai');

describe('LiftoffSettings', function () {
  let LiftoffSettings;

  beforeEach(async function () {
    LiftoffSettings = await ethers.getContractFactory("LiftoffSettings");
    liftoffSettings = await upgrades.deployProxy(LiftoffSettings, []);// add initializer here eg .deployProxy(Box, [42], {initializer: 'store'});
    await liftoffSettings.deployed();
  });
 
  it('set/get EthXLockBP', async function () {
    await liftoffSettings.setEthXLockBP(1000);
    expect((await liftoffSettings.getEthXLockBP()).toString()).to.equal("1000");
  });

  it('set/get TokenUserBP', async function () {
    await liftoffSettings.setTokenUserBP(1000);
    expect((await liftoffSettings.getTokenUserBP()).toString()).to.equal("1000");
  });

  it('set/get LiftoffInsurance', async function () {
    const [liftOffInsurance] = await ethers.getSigners();
    await liftoffSettings.setLiftoffInsurance(liftOffInsurance.address);
    expect((await liftoffSettings.getLiftoffInsurance()).toString()).to.equal(liftOffInsurance.address.toString());
  });

  it('set/get LiftoffLauncher', async function () {
    const [liftOffLauncher] = await ethers.getSigners();
    await liftoffSettings.setLiftoffLauncher(liftOffLauncher.address);
    expect((await liftoffSettings.getLiftoffLauncher()).toString()).to.equal(liftOffLauncher.address.toString());
  });

  it('set/get LiftoffEngine', async function () {
    const [liftOffEngine] = await ethers.getSigners();
    await liftoffSettings.setLiftoffEngine(liftOffEngine.address);
    expect((await liftoffSettings.getLiftoffEngine()).toString()).to.equal(liftOffEngine.address.toString());
  });

  it('set/get XEth', async function () {
    const [xEth] = await ethers.getSigners();
    await liftoffSettings.setXEth(xEth.address);
    expect((await liftoffSettings.getXEth()).toString()).to.equal(xEth.address.toString());
  });

  it('set/get XLocker', async function () {
    const [xLocker] = await ethers.getSigners();
    await liftoffSettings.setXLocker(xLocker.address);
    expect((await liftoffSettings.getXLocker()).toString()).to.equal(xLocker.address.toString());
  });

  it('set/get UniswapRouter', async function () {
    const [uniswapRouter] = await ethers.getSigners();
    await liftoffSettings.setUniswapRouter(uniswapRouter.address);
    expect((await liftoffSettings.getUniswapRouter()).toString()).to.equal(uniswapRouter.address.toString());
  });

  it('set/get InsurancePeriod', async function () {
    await liftoffSettings.setInsurancePeriod(604800);
    expect((await liftoffSettings.getInsurancePeriod()).toString()).to.equal("604800");
  });

  it('set/get LidTreasury', async function () {
    const [lidTreasury] = await ethers.getSigners();
    await liftoffSettings.setLidTreasury(lidTreasury.address);
    expect((await liftoffSettings.getLidTreasury()).toString()).to.equal(lidTreasury.address.toString());
  });

  it('set/get LidPoolManager', async function () {
    const [lidPoolManager] = await ethers.getSigners();
    await liftoffSettings.setLidPoolManager(lidPoolManager.address);
    expect((await liftoffSettings.getLidPoolManager()).toString()).to.equal(lidPoolManager.address.toString());
  });

  it('setXethBP should revert if sum of BP params is less than 10000', async function () {
    await expectRevert(liftoffSettings.setXethBP(1000, 2000, 3000, 2000, 1000), "Must allocate 100% of eth raised");
  });

  it('set/get XethBP Params', async function () {
    await liftoffSettings.setXethBP(1000, 2000, 3000, 2000, 2000);
    expect((await liftoffSettings.getBaseFeeBP()).toString()).to.equal("1000");
    expect((await liftoffSettings.getEthBuyBP()).toString()).to.equal("2000");
    expect((await liftoffSettings.getProjectDevBP()).toString()).to.equal("3000");
    expect((await liftoffSettings.getMainFeeBP()).toString()).to.equal("2000");
    expect((await liftoffSettings.getLidPoolBP()).toString()).to.equal("2000");
  });
});
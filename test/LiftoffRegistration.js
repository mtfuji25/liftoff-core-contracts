const { expect } = require('chai');
const { ether, time } = require("@openzeppelin/test-helpers");

describe('LiftoffRegistration', function () {
  let liftoffRegistration;

  before(async function () {
    const [liftoffEngine] = await ethers.getSigners();
    LiftoffRegistration = await ethers.getContractFactory("LiftoffRegistration");
    liftoffRegistration = await upgrades.deployProxy(
      LiftoffRegistration, 
      [time.duration.hours(24).toNumber(), 
        time.duration.days(7).toNumber(), 
        time.duration.hours(24).toNumber(), 
        liftoffEngine.address]
      );
    await liftoffRegistration.deployed();
  });
 
  describe('registerProject', async function () {
    it('should revert if launchTime is before minLaunchTime', async function () {
      const currentTime = await time.latest();
      await expect(liftoffRegistration.registerProject(
        "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t", 
        currentTime.toNumber(), 
        100000000, 
        1000000000, 
        10000000000, 
        "TestToken", 
        "tkn"
      )).to.be.revertedWith("Not allowed to launch before minLaunchTime");
    });

    it('should revert if launchTime is after maxLaunchTime', async function () {
      await time.increase(time.duration.hours(1));
      await time.advanceBlock();
      const currentTime = await time.latest();
      await expect(liftoffRegistration.registerProject(
        "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t", 
        currentTime.toNumber() + time.duration.days(7).toNumber(), 
        100000000, 
        1000000000, 
        10000000000, 
        "TestToken", 
        "tkn"
      )).to.be.revertedWith("Not allowed to launch after maxLaunchTime");
    });

    it('should revert if totalSupplyWad is more than 1 trillion', async function () {
      await time.increase(time.duration.days(1));
      await time.advanceBlock();
      const currentTime = await time.latest();
      await expect(liftoffRegistration.registerProject(
        "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t", 
        currentTime.toNumber(), 
        100000000, 
        1000000000, 
        ether("1000000000000").toString(), // 1 trillion
        "TestToken", 
        "tkn"
      )).to.be.revertedWith("Cannot launch more than 1 trillion tokens");
    });
  });
});
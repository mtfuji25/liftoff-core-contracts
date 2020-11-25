const { accounts, contract } = require("@openzeppelin/test-environment")
const { expectRevert, time } = require("@openzeppelin/test-helpers")

const LiftoffRegistration = contract.fromArtifact("LiftoffRegistration")

const owner = accounts[0]

describe("LiftoffRegistration", function () {
  before(async function () {
    this.LiftoffRegistration = await LiftoffRegistration.new()
    await this.LiftoffRegistration.initialize(owner)
    await this.LiftoffRegistration.setLaunchTimeDelta(time.duration.days(1), time.duration.days(360), { from: owner })
  })

  describe("registerProject", function () {  
    it("Should revert if launchTime is before minLaunchTime", async function () {
      const currentTime = await time.latest()
      await expectRevert(
        this.LiftoffRegistration.registerProject(
          "",
          "",
          "",
          currentTime.toNumber() + time.duration.hours(1).toNumber(), // 1 hour in future
        ),
        "Not allowed to launch before minLaunchTime"
      )
    })

    it("Should revert if launchTime is after maxLaunchTime", async function () {
      const currentTime = await time.latest()
      await expectRevert(
        this.LiftoffRegistration.registerProject(
          "",
          "",
          "",
          currentTime.toNumber() + time.duration.days(361).toNumber(), // 1 hour in future
        ),
        "Not allowed to launch after maxLaunchTime"
      )
    })
  })
})

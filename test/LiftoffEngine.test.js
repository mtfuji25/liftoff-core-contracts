const { accounts, contract } = require("@openzeppelin/test-environment")
const {
  expectRevert,
  time,
  ether,
  balance,
} = require("@openzeppelin/test-helpers")
const { expect } = require("chai")

const LiftoffEngine = contract.fromArtifact("LiftoffEngine")
const LiftoffSwap = contract.fromArtifact("LiftoffSwap")
const Token = contract.fromArtifact("Token")

const owner = accounts[0]
const projectDev = accounts[1]
const newProjectDev = accounts[2]
const ignitors = [accounts[3], accounts[4]]
const lidTreasury = accounts[5]
const liftoffLauncher = accounts[6]

describe("LiftoffEngine", function () {
  before(async function () {
    this.Engine = await LiftoffEngine.new()
    this.LiftoffSwap = await LiftoffSwap.new()

    await this.Engine.initialize(
      liftoffLauncher,
      lidTreasury,
      this.LiftoffSwap.address,
      7000,
      3000,
      3000,
      1000,
      time.duration.hours(24),
      owner
    )

    await this.LiftoffSwap.init(owner)
    await this.LiftoffSwap.setLiftoffEngine(this.Engine.address,{
      from: owner
    })

    this.Token = await Token.new()
    this.totalTokens = ether("100000")
    await this.Token.initialize(this.totalTokens, liftoffLauncher)
    await this.Token.approve(this.Engine.address, this.totalTokens, {
      from: liftoffLauncher,
    })
  })

  describe("Stateless", function() {
    describe("launchToken", function () {  
      it("Should revert if sender is not Launcher", async function () {
        await expectRevert(
          this.Engine.launchToken(
            this.Token.address,
            projectDev,
            this.totalTokens,
            time.duration.days(7),
            0 // startTime
          ),
          "Sender must be launcher"
        )
      })
  
      it("Should revert if Launcher does not have enough tokens", async function () {
        await expectRevert(
          this.Engine.launchToken(
            this.Token.address,
            projectDev,
            this.totalTokens + ether("10"),
            time.duration.days(7),
            0, // startTime
            { from: liftoffLauncher }
          ),
          "ERC20: transfer amount exceeds balance"
        )
      })
    })
  })

  describe("State: Before Liftoff Launch",function() {
    before(async function(){
      const currentTime = await time.latest()
      await this.Engine.launchToken(
        this.Token.address,
        projectDev,
        this.totalTokens,
        time.duration.days(7),
        currentTime.toNumber() + time.duration.hours(1).toNumber(), // 1 hour in future
        { from: liftoffLauncher }
      )
    })

    describe("ignite", function () {
      it("Should revert if block.timestamp is after token startTime", async function () {
        await expectRevert(
          this.Engine.ignite(
            this.Token.address,
            { from: owner }
          ),
          "Token not yet available"
        )
      })
    })

    describe("spark", function () {
      it("Should revert if token not started yet", async function () {
        await expectRevert(
          this.Engine.spark(this.Token.address),
          "Must be after sparkPeriod ends"
        )
      })
    })

    describe("claimReward", function() {
      it("Should revert if token not started yet", async function () {
        await expectRevert(
          this.Engine.claimReward(
            this.Token.address,
            { from: owner }
          ),
          "No rewards claimable before spark"
        )
      })
    })
  })

  describe("State: Pre Spark",function() {
    before(async function () {
      //Advance forward 1 hour into post launch but pre spark period
      await time.increase(
        time.duration.hours(1)
      )
      await time.advanceBlock()
    })

    describe("spark", function () {
      it("Should revert if it's in sparkPeriod", async function () {
        await expectRevert(
          this.Engine.spark(this.Token.address),
          "Must be after sparkPeriod ends"
        )
      })
    })
    
    describe("ignite", function () {
      it("Should ignite and share to projectDev and lidTreasury", async function () {
        // first ignitor
        await this.Engine.ignite(
          this.Token.address,
          { from: owner, value: ether("10") }
        )
        expect((await balance.current(projectDev)).toString()).to.equal(ether("107").toString())
        expect((await balance.current(lidTreasury)).toString()).to.equal(ether("103").toString())
  
        let tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("10").toString())

        // second ignitor
        await this.Engine.ignite(
          this.Token.address,
          { from: ignitors[0], value: ether("20") }
        )
        expect((await balance.current(projectDev)).toString()).to.equal(ether("121").toString())
        expect((await balance.current(lidTreasury)).toString()).to.equal(ether("109").toString())
  
        tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("30").toString())

        // third ignitor
        await this.Engine.ignite(
          this.Token.address,
          { from: ignitors[1], value: ether("30") }
        )
        expect((await balance.current(projectDev)).toString()).to.equal(ether("142").toString())
        expect((await balance.current(lidTreasury)).toString()).to.equal(ether("118").toString())
  
        tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("60").toString())
      })
    })

    describe("claimReward", function() {
      it("Should revert if it's not spark period", async function () {
        await expectRevert(
          this.Engine.claimReward(
            this.Token.address,
            { from: owner }
          ),
          "No rewards claimable before spark"
        )
      })
    })
  })

  describe("State: Post Spark", function () {
    before(async function(){
      //Advance forward 24 hours into post spark period
      await time.increase(
        time.duration.hours(24)
      )
      await time.advanceBlock()
      await this.Engine.spark(this.Token.address)
    })

    describe("spark", function () {
      it("Should revert if token already sparked", async function () {
        await expectRevert(
          this.Engine.spark(this.Token.address),
          "Token already sparked"
        )
      })
    })

    describe("ignite", function () {
      it("Should ignite and share to projectDev and lidTreasury", async function () {
        await this.Engine.ignite(
          this.Token.address,
          { from: owner, value: ether("10") }
        )
        expect((await balance.current(projectDev)).toString()).to.equal(ether("149").toString())
        expect((await balance.current(lidTreasury)).toString()).to.equal(ether("121").toString())
  
        const tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("70").toString())
      })
    })

    describe("getIgnitor", function() {
      it("Should get ignitor balance", async function () {
        const ignitor = await this.Engine.getIgnitor(this.Token.address, owner)
        expect(ignitor.balance.toString()).to.equal(ether("20").toString())
      })
    })

    describe("getEarned", function() {
      it("Should increase by almost 85 ether per hour", async function () {
        const amountInitial = await this.Engine.getEarned(this.Token.address, owner)
        await time.increase(
          time.duration.hours(1)
        )
        await time.advanceBlock()
        const amountFinal = await this.Engine.getEarned(this.Token.address, owner)
        // current ignitors
        // owner: 20 ether
        // ignitors[0]: 20 ether
        // ignitors[1]: 30 ether
        // owner income/h = 50000 * (20/70) / (7*24)
        expect(amountFinal.sub(amountInitial)).to.be.bignumber.above(ether("85.0"))
        expect(amountFinal.sub(amountInitial)).to.be.bignumber.below(ether("85.1"))
      })
    })

    describe("claimReward", function () {
      it("Should claim rewards and share it to projectDev and lidTreasury", async function () {
        await this.Engine.claimReward(
          this.Token.address,
          { from: owner }
        )
        
        const unclaimedTokens = (await this.Engine.getToken(this.Token.address)).unclaimedTokens
        const rewards = ether("50000") - unclaimedTokens
        const projectDevReward = await this.Token.balanceOf(projectDev)
        const lidTreasuryReward = await this.Token.balanceOf(lidTreasury)
        const ownerReward = await this.Token.balanceOf(owner)
        
        expect(projectDevReward.toString()).to.be.bignumber.above((rewards*0.29).toString())
        expect(projectDevReward.toString()).to.be.bignumber.below((rewards*0.31).toString())
        expect(lidTreasuryReward.toString()).to.be.bignumber.above((rewards*0.09).toString())
        expect(lidTreasuryReward.toString()).to.be.bignumber.below((rewards*0.11).toString())
        expect(ownerReward.toString()).to.be.bignumber.above((rewards*0.59).toString())
        expect(ownerReward.toString()).to.be.bignumber.below((rewards*0.61).toString())
      })
    })

    describe("mutiny", function() {
      it("Should revert if caller is not the owner", async function () {
        await expectRevert(
          this.Engine.mutiny(
            this.Token.address,
            newProjectDev
          ),
          "Ownable: caller is not the owner"
        )
      })
    })

    describe("setGovernanceProperties", function() {
      it("Should revert if caller is not the owner", async function () {
        await expectRevert(
          this.Engine.setGovernanceProperties(
            liftoffLauncher,
            lidTreasury,
            this.LiftoffSwap.address,
            7000,
            3000,
            3000,
            1000
          ),
          "Ownable: caller is not the owner"
        )
      })
    })
  })

  describe("State: Second Halving", function () {
    before(async function(){
      //Advance forward 24 hours into post spark period
      await time.increase(
        time.duration.days(7)
      )
      await time.advanceBlock()

      // Remaining unclaimed tokens in the prev halving
      this.prevUnclaimedTokens = (await this.Engine.getToken(this.Token.address)).unclaimedTokens
      this.prevProjectDevReward = await this.Token.balanceOf(projectDev)
      this.prevLidTreasuryReward = await this.Token.balanceOf(lidTreasury)
      this.prevOwnerReward = await this.Token.balanceOf(owner)

      await this.Engine.ignite(
        this.Token.address,
        { from: owner, value: ether("10") }
      )
    })

    describe("getEarned", function() {
      it("Should increase by almost 55.8 ether per hour", async function () {
        const amountInitial = await this.Engine.getEarned(this.Token.address, owner)
        await time.increase(
          time.duration.hours(1)
        )
        await time.advanceBlock()
        const amountFinal = await this.Engine.getEarned(this.Token.address, owner)
        // current ignitors
        // owner: 30 ether
        // ignitors[0]: 20 ether
        // ignitors[1]: 30 ether
        // owner income/h = 25000 * (30/80) / (7*24)
        expect(amountFinal.sub(amountInitial)).to.be.bignumber.above(ether("55.8"))
        expect(amountFinal.sub(amountInitial)).to.be.bignumber.below(ether("55.9"))
      })
    })

    describe("claimReward", function () {
      it("Should claim rewards and share it to projectDev and lidTreasury", async function () {
        const unclaimedTokensBeforeClaim = (await this.Engine.getToken(this.Token.address)).unclaimedTokens
        expect(this.prevUnclaimedTokens.add(ether("25000"))).to.be.bignumber.equal(unclaimedTokensBeforeClaim)
        await this.Engine.claimReward(
          this.Token.address,
          { from: owner }
        )
        
        const unclaimedTokensAfterClaim = (await this.Engine.getToken(this.Token.address)).unclaimedTokens
        const rewards = this.prevUnclaimedTokens.add(ether("25000")).sub(unclaimedTokensAfterClaim)
        let projectDevReward = (await this.Token.balanceOf(projectDev)).sub(this.prevProjectDevReward)
        let lidTreasuryReward = (await this.Token.balanceOf(lidTreasury)).sub(this.prevLidTreasuryReward)
        let ownerReward = (await this.Token.balanceOf(owner)).sub(this.prevOwnerReward)
        
        expect(projectDevReward.toString()).to.be.bignumber.above((rewards*0.29).toString())
        expect(projectDevReward.toString()).to.be.bignumber.below((rewards*0.31).toPrecision(23).toString())
        expect(lidTreasuryReward.toString()).to.be.bignumber.above((rewards*0.09).toString())
        expect(lidTreasuryReward.toString()).to.be.bignumber.below((rewards*0.11).toPrecision(23).toString())
        expect(ownerReward.toString()).to.be.bignumber.above((rewards*0.59).toString())
        expect(ownerReward.toString()).to.be.bignumber.below((rewards*0.61).toPrecision(23).toString())
      })
    })
  })
})

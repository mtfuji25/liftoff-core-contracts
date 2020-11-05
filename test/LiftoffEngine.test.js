const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const {
  expectRevert,
  time,
  BN,
  ether,
  balance,
} = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const LiftoffEngine = contract.fromArtifact("LiftoffEngine");
const LiftoffSwap = contract.fromArtifact("LiftoffSwap");
const Token = contract.fromArtifact("Token");

const owner = accounts[0];
const projectDev = accounts[1];
const depositors = [accounts[2], accounts[3], accounts[4], accounts[5]];
const lidTreasury = accounts[6];
const liftoffLauncher = accounts[7];

describe("LiftoffEngine", function () {
  before(async function () {
    this.Engine = await LiftoffEngine.new();
    this.LiftoffSwap = await LiftoffSwap.new();
    this.Token = await Token.new();

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
    );

    await this.LiftoffSwap.init(owner);
    await this.LiftoffSwap.setLiftoffEngine(this.Engine.address,{
      from: owner
    })

    this.Token = await Token.new();
    this.totalTokens = ether("100000")
    await this.Token.initialize(this.totalTokens, liftoffLauncher);
    await this.Token.approve(this.Engine.address, this.totalTokens, {
      from: liftoffLauncher,
    });
  });

  describe("Stateless", function() {
    describe("launchToken", function () {  
      it("Should revert if sender is not Launcher", async function () {
        await expectRevert(
          this.Engine.launchToken(
            this.Token.address,
            projectDev,
            this.totalTokens,
            7*24*3600, //7 days
            0 // startTime
          ),
          "Sender must be launcher"
        );
      });
  
      it("Should revert if Launcher does not have enough tokens", async function () {
        await expectRevert(
          this.Engine.launchToken(
            this.Token.address,
            projectDev,
            this.totalTokens + ether("10"),
            7*24*3600, //7 days
            0, // startTime
            { from: liftoffLauncher }
          ),
          "ERC20: transfer amount exceeds balance"
        );
      });
    });
  });

  describe("State: Before Liftoff Launch",function() {
    before(async function(){
      const currentTime = await time.latest();
      await this.Engine.launchToken(
        this.Token.address,
        projectDev,
        this.totalTokens,
        time.duration.days(7).toNumber(), //7 days
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
        );
      });
    });
  })

  describe("State: Pre Spark",function() {
    before(async function () {
      //Advance forward 1 hour into post launch but pre spark period
      await time.increase(
        time.duration.hours(1)
      )
      await time.advanceBlock()
    })
    
    describe("ignite", function () {
      it("Should revert if it's not spark period", async function () {
        await expectRevert(
          this.Engine.claimReward(
            this.Token.address,
            { from: owner }
          ),
          "No rewards claimable before spark"
        );
      });

      it("Should ignite and share to projectDev and lidTreasury", async function () {  
        await this.Engine.ignite(
          this.Token.address,
          { from: owner, value: "10000000000000000000" }
        )
        expect((await balance.current(projectDev)).valueOf().toString()).to.equal("107000000000000000000");
        expect((await balance.current(lidTreasury)).valueOf().toString()).to.equal("103000000000000000000");
  
        const tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo["0"].valueOf().toString()).to.equal("10000000000000000000");
        expect(tokenInfo.totalIgnited.valueOf().toString()).to.equal("10000000000000000000");
      });
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

    describe("ignite", function () {
      it("Should ignite and share to projectDev and lidTreasury", async function () {  
        await this.Engine.ignite(
          this.Token.address,
          { from: owner, value: "10000000000000000000" }
        )
        expect((await balance.current(projectDev)).valueOf().toString()).to.equal("107000000000000000000");
        expect((await balance.current(lidTreasury)).valueOf().toString()).to.equal("103000000000000000000");
  
        const tokenInfo = await this.Engine.getToken(this.Token.address)
        expect(tokenInfo["0"].valueOf().toString()).to.equal("10000000000000000000");
        expect(tokenInfo.totalIgnited.valueOf().toString()).to.equal("10000000000000000000");
      });
    });

    describe("claimReward", function () {
      it("Should claim rewards and share it to projectDev and lidTreasury", async function () {
        await this.Engine.claimReward(
          this.Token.address,
          { from: owner }
        )
        //TODO: Check token distribution
      });
    });

  });
});

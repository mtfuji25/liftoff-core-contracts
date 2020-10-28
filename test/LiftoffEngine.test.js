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
      owner
    );

    await this.LiftoffSwap.init(owner);
  });

  describe("launchToken", function () {
    before(async function () {
      this.Token = await Token.new();

      await this.Token.initialize(ether("100000"), liftoffLauncher);

      await this.Token.approve(this.Engine.address, ether("100000"), {
        from: liftoffLauncher,
      });
    });

    const amount_of_tokens = ether("100000");

    it("Should revert if sender is not Launcher", async function () {
      await expectRevert(
        this.Engine.launchToken(
          this.Token.address,
          projectDev,
          amount_of_tokens,
          20,
          10000
        ),
        "Only callable by lanucher address."
      );
      throw "not implemented";
    });

    it("Should revert if Launcher does not have enough tokens", async function () {
      await expectRevert(
        this.Engine.launchToken(
          this.Token.address,
          projectDev,
          amount_of_tokens + ether("10"),
          20,
          10000,
          { from: liftoffLauncher }
        ),
        "Lanucher must have enough tokens"
      );
      throw "not implemented";
    });

    describe("On success", function () {
      before(async function () {});
    });
  });
});

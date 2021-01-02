const chai = require('chai');
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ether, time, BN } = require("@openzeppelin/test-helpers");
const { UniswapDeployAsync } = require("../tools/UniswapDeployAsync");
const { XLockDeployAsync } = require("../tools/XLockDeployAsync");
const loadJsonFile = require('load-json-file');
const settings = loadJsonFile.sync("./scripts/settings.json").networks.hardhat;

chai.use(solidity);

describe('LiftoffInsurance', function () {
  let liftoffSettings, liftoffEngine;
  let liftoffInsurance, sweepReceiver, projectDev, ignitor1, ignitor2, ignitor3;

  before(async function () {
    const accounts = await ethers.getSigners();
    liftoffRegistration = accounts[0];
    sweepReceiver = accounts[1];
    projectDev = accounts[2];
    ignitor1 = accounts[3];
    ignitor2 = accounts[4];
    ignitor3 = accounts[5];
    lidTreasury = accounts[6];
    lidPoolManager = accounts[7];

    upgrades.silenceWarnings();

    const { uniswapV2Router02, uniswapV2Factory } = await UniswapDeployAsync(ethers);
    const { xEth, xLocker} = await XLockDeployAsync(ethers, sweepReceiver, uniswapV2Factory, uniswapV2Router02);

    LiftoffSettings = await ethers.getContractFactory("LiftoffSettings");
    liftoffSettings = await upgrades.deployProxy(LiftoffSettings, []);
    await liftoffSettings.deployed();

    LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance");
    liftoffInsurance = await upgrades.deployProxy(LiftoffInsurance, [liftoffSettings.address], { unsafeAllowCustomTypes: true });
    await liftoffInsurance.deployed();    

    LiftoffEngine = await ethers.getContractFactory("LiftoffEngine");
    liftoffEngine = await upgrades.deployProxy(LiftoffEngine, [liftoffSettings.address], { unsafeAllowCustomTypes: true });
    await liftoffEngine.deployed();

    await liftoffSettings.setAllUints(
      settings.ethXLockBP,
      settings.tokenUserBP,
      settings.insurancePeriod,
      settings.baseFeeBP,
      settings.ethBuyBP,
      settings.projectDevBP,
      settings.mainFeeBP,
      settings.lidPoolBP
    );

    await liftoffSettings.setAllAddresses(
      liftoffInsurance.address,
      liftoffRegistration.address,
      liftoffEngine.address,
      xEth.address,
      xLocker.address,
      uniswapV2Router02.address,
      lidTreasury.address,
      lidPoolManager.address
    );
  });

  describe("Stateless", function() {
    describe("isInsuranceExhausted", function() {
      let currentTime, startTime, insurancePeriod, xEthValue, baseXEth, redeemedXEth, isUnwound;
      before(async function () {
        startTime = await time.latest();
        insurancePeriod = new BN(settings.insurancePeriod);
        currentTime = startTime.add(insurancePeriod).add(time.duration.days(1));
        xEthValue = ether("10");
        baseXEth = ether("100");
        redeemedXEth = ether("100");
        isUnwound = false;
      });
      it("Should be true if not isUnwound, currentTime > startTime+insurancePeriod, and baseXEth < redeemedXEth + xEthValue", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          currentTime.toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          redeemedXEth.toString(),
          isUnwound
        );
        expect(isExhausted).to.be.true;
      });
      it("Should be false if isUnwound", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          currentTime.toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          redeemedXEth.toString(),
          true
        );
        expect(isExhausted).to.be.false;
      });
      it("Should be false if currentTime <= startTime+insurancePeriod", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          startTime.add(insurancePeriod).toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          redeemedXEth.toString(),
          isUnwound
        );
        expect(isExhausted).to.be.false;
      });
      it("Should be false if baseXEth > redeemedXEth + xEthValue", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          currentTime.toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          ether("0").toString(),
          isUnwound
        );
        expect(isExhausted).to.be.false;
      });
    });
    describe("canCreateInsurance", function() {
      let insuranceIsInitialized, tokenIsRegistered;
      before(async function() {
        insuranceIsInitialized = false;
        tokenIsRegistered = true;
      });
      it("Should be true if not insuranceIsInitialized and is tokenRegistered", async function() {
        const canCreateInsurance = await liftoffInsurance.canCreateInsurance(
          insuranceIsInitialized,
          tokenIsRegistered
        );
        expect(canCreateInsurance).to.be.true;
      });
      it("Should be false if insuranceIsInitialized", async function() {
        const canCreateInsurance = await liftoffInsurance.canCreateInsurance(
          true,
          tokenIsRegistered
        );
        expect(canCreateInsurance).to.be.false;
      });
      it("Should be false if not tokenRegistered", async function() {
        const canCreateInsurance = await liftoffInsurance.canCreateInsurance(
          insuranceIsInitialized,
          false
        );
        expect(canCreateInsurance).to.be.false;
      });
    });
    describe("getRedeemValue", function() {
      it("Should be equal to amount divided by tokens/eth when price is above one", async function() {
        const amount = ether("3193.12321");
        const tokensPerEthWad = ether("3241.2313");
        const redeemValue = await liftoffInsurance.getRedeemValue(
          amount.toString(),
          tokensPerEthWad.toString()
        );
        const expectedAmount = amount.mul(ether("1")).div(tokensPerEthWad).toString();
        expect(redeemValue).to.be.bignumber.above(ether("0.8").toString());
        expect(redeemValue).to.be.bignumber.below(ether("1").toString());
        expect(redeemValue).to.be.bignumber.equal(expectedAmount);
      });
      it("Should be equal to amount divided by tokens/eth when price is below one", async function() {
        const amount = ether("0.12321");
        const tokensPerEthWad = ether("0.001313121187");
        const redeemValue = await liftoffInsurance.getRedeemValue(
          amount.toString(),
          tokensPerEthWad.toString()
        );
        const expectedAmount = amount.mul(ether("1")).div(tokensPerEthWad).toString();
        expect(redeemValue).to.be.bignumber.above(ether("80").toString());
        expect(redeemValue).to.be.bignumber.below(ether("100").toString());
        expect(redeemValue).to.be.bignumber.equal(expectedAmount);
      });
    });
    describe("getTotalTokenClaimable", function() {
      it("Should be 0 when cycles are 0", async function() {
        const totalClaimable = await liftoffInsurance.getTotalTokenClaimable(
          ether("12000").toString(),
          0,
          0
        );
        expect(totalClaimable).to.be.bignumber.equal(0);
      });
      it("Should be base*cycles/10-claimed when cycles less than 10", async function() {
        const base = ether("12000");
        const claimed = ether("3600");
        const cycles = new BN("6");
        const totalClaimable = await liftoffInsurance.getTotalTokenClaimable(
          base.toString(),
          cycles.toString(),
          claimed.toString()
        );
        expect(totalClaimable).to.be.bignumber.equal(base.mul(cycles).div(new BN("10")).sub(claimed).toString());
      });
      it("Should be base-claimed when cycles greater than 10", async function() {
        const base = ether("12000");
        const claimed = ether("3600");
        const cycles = new BN("11");
        const totalClaimable = await liftoffInsurance.getTotalTokenClaimable(
          base.toString(),
          cycles.toString(),
          claimed.toString()
        );
        expect(totalClaimable).to.be.bignumber.equal(base.sub(claimed).toString());
      });
    });
    describe("getTotalXethClaimable", function() {
      let totalIgnited, redeemedXEth, claimedXeth;
      before(async function() {
        totalIgnited = ether("3500");
        redeemedXEth = ether("1200");
        claimedXeth = ether("230");
        cycles = new BN("3");
      })
      it("Should be 0 when cycles are 0", async function() {
        const totalClaimable = await liftoffInsurance.getTotalXethClaimable(
          totalIgnited.toString(),
          redeemedXEth.toString(),
          claimedXeth.toString(),
          0
        );
        expect(totalClaimable).to.be.bignumber.equal(0);
      });
      //TODO: Fix LiftoffInsurance.getTotalXethClaimable to not use totalIgnited
      //Instead, should use totalIgnited - total buy - base fees 
      /*it("Should be (total - redeemed * cycles / 10 when cycles are 3", async function() {
        const totalClaimable = await liftoffInsurance.getTotalXethClaimable(
          totalIgnited.toString(),
          redeemedXEth.toString(),
          claimedXeth.toString(),
          0
        );
        const expectedValue = totalIgnited.sub(redeemedXEth). 
        expect(totalClaimable).to.be.bignumber.equal(expectedValue.toString());
      });*/
    });
  });
  describe("State: PreRegisteration", function() {
    describe("register", function() {
      it("should revert if sender is not liftoffEngine", async function() {
        await expect(
          liftoffInsurance.register(0)
        ).to.be.revertedWith("Sender must be Liftoff Engine")
      });
    });
    describe("redeem", function() {
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.redeem(0,0)
        ).to.be.revertedWith("Insurance not initialized")
      });
    });
    describe("claim", function() {
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.claim(0)
        ).to.be.revertedWith("Insurance not initialized")
      });
    });
    describe("createInsurance", function() {
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.createInsurance(0)
        ).to.be.revertedWith("Cannot create insurance")
      });
    });
  });
  describe("State: Insurance Registered", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
  describe("State: Insurance Initialized", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
  describe("State: Insurance Cycle 1", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
  describe("State: Insurance Cycle 5", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
  describe("State: Insurance Cycle 11", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
  describe("State: Insurance Exhausted", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });*/
  });
});
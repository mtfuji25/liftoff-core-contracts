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
  let IERC20;

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

    IERC20 = await ethers.getContractAt("@uniswap\\v2-core\\contracts\\interfaces\\IERC20.sol:IERC20",ethers.constants.AddressZero)

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
    let tokenSaleId, tokenSaleId2;
    describe("isInsuranceExhausted", function() {
      let currentTime, startTime, insurancePeriod, xEthValue, 
        claimedXEth, baseXEth, redeemedXEth, isUnwound;
      before(async function () {
        startTime = await time.latest();
        insurancePeriod = new BN(settings.insurancePeriod);
        currentTime = startTime.add(insurancePeriod).add(time.duration.days(1));
        xEthValue = ether("10");
        baseXEth = ether("100");
        redeemedXEth = ether("75");
        claimedXEth = ether("20");
        isUnwound = false;
      });
      it("Should be true if not isUnwound, currentTime > startTime+insurancePeriod, and baseXEth < redeemedXEth + claimedXeth + xEthValue", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          currentTime.toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          redeemedXEth.toString(),
          claimedXEth.toString(),
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
          claimedXEth.toString(),
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
          claimedXEth.toString(),
          isUnwound
        );
        expect(isExhausted).to.be.false;
      });
      it("Should be false if baseXEth > redeemedXEth + xEthValue + claimedXEth", async function() {
        const isExhausted = await liftoffInsurance.isInsuranceExhausted(
          currentTime.toString(),
          startTime.toString(),
          insurancePeriod.toString(),
          xEthValue.toString(),
          baseXEth.toString(),
          ether("0").toString(),
          claimedXEth.toString(),
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
      it("Should be (total - redeemedXeth - claimedXeth)  * cycles / 10 - claimed when cycles are 3", async function() {
        const totalClaimable = await liftoffInsurance.getTotalXethClaimable(
          totalIgnited.toString(),
          redeemedXEth.toString(),
          claimedXeth.toString(),
          cycles.toString()
        );
        const expectedValue = totalIgnited.sub(redeemedXEth).sub(claimedXeth).mul(cycles).div(new BN("10"));
        expect(totalClaimable).to.be.bignumber.equal(expectedValue.toString());
      });
      it("Should be (total - redeemedXeth - claimed when cycles are greater than 10", async function() {
        const totalClaimable = await liftoffInsurance.getTotalXethClaimable(
          totalIgnited.toString(),
          redeemedXEth.toString(),
          claimedXeth.toString(),
          "12"
        );
        const expectedValue = totalIgnited.sub(redeemedXEth).sub(claimedXeth);
        expect(totalClaimable).to.be.bignumber.equal(expectedValue.toString());
      });
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
  describe("State: Cycle 0", function() {
    let tokenInsurance, tokenSale;
    before(async function(){
      const currentTime = await time.latest();
      tokenSaleId = await liftoffEngine.launchToken(
        currentTime.toNumber() + time.duration.hours(1).toNumber(),
        currentTime.toNumber() + time.duration.days(7).toNumber(),
        ether("500").toString(),
        ether("1000").toString(),
        ether("10000").toString(),
        "TestToken",
        "TKN",
        projectDev.address
      );
      await time.increase(
        time.duration.days(1)
      );
      await time.advanceBlock();

      await liftoffEngine.connect(ignitor1).igniteEth(
        tokenSaleId.value,
          { value: ether("300").toString() }
      );
      await liftoffEngine.connect(ignitor2).igniteEth(
        tokenSaleId.value,
          { value: ether("200").toString() }
      );
      await liftoffEngine.connect(ignitor3).igniteEth(
        tokenSaleId.value,
          { value: ether("600").toString() }
      );
      await time.increase(
        time.duration.days(6)
      );
      await time.advanceBlock();
    });
    describe("register", function() {
      it("should register new token", async function() {
        await expect(liftoffEngine.spark(tokenSaleId.value))
        .to.emit(liftoffInsurance,'Register')
        .withArgs(tokenSaleId.value);
      });
      it("should set tokenIsRegistered[id] to true", async function() {
        const isRegistered = await liftoffInsurance.tokenIsRegistered(0);
        expect(isRegistered).to.be.true;
      });
    });
    describe("createInsurance", function() {
      let currentTime;
      before(async function() {
        await liftoffInsurance.createInsurance(tokenSaleId.value);
        currentTime = await time.latest();
        const tokenInsuranceUints = await liftoffInsurance.getTokenInsuranceUints(tokenSaleId.value);
        const tokenInsuranceOthers = await liftoffInsurance.getTokenInsuranceOthers(tokenSaleId.value);
        tokenInsurance = Object.assign({}, tokenInsuranceUints, tokenInsuranceOthers);
        tokenSale = await liftoffEngine.getTokenSaleForInsurance(tokenSaleId.value);
      });
      it("should revert if run again", async function() {
        await expect(
          liftoffInsurance.createInsurance(tokenSaleId.value)
        ).to.be.revertedWith("Cannot create insurance")
      });
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.createInsurance(tokenSaleId.value+1)
        ).to.be.revertedWith("Cannot create insurance")
      });
      it("should set insuranceIsInitialized[tokensaleid] to true", async function () {
        const isInitialized = await liftoffInsurance.insuranceIsInitialized(tokenSaleId.value);
        expect(isInitialized).to.be.true;
      });
      it("should set tokenInsurance.startTime to current time.", async function() {
        expect(tokenInsurance.startTime).to.equal(currentTime.toNumber());
      });
      it("should set tokenInsurance.totalIgnited to liftoffEngine totalIgnited", async function() {
        expect(tokenInsurance.totalIgnited).to.equal(tokenSale.totalIgnited);
      });
      it("Should set tokensPerEthWad s.t. rewardSupply/tokensPerEth = totalIgnited minus base fee", async function() {
        expect(tokenInsurance.tokensPerEthWad).to.be.gt(ether("0.01").toString());
        expect(tokenInsurance.tokensPerEthWad).to.be.lt(ether("100").toString());
        const calcValue = tokenSale.rewardSupply
          .mul(ether("1").toString())
          .div(tokenInsurance.tokensPerEthWad);
        const expValue = tokenInsurance.totalIgnited.mul(10000-settings.baseFeeBP).div(10000);
        expect(calcValue).to.be.lt(expValue);
        expect(calcValue).to.be.gt(expValue.sub(100));
      })
      it("should set baseXEth to total ignited minus buy", async function() {
        expect(tokenInsurance.baseXEth).to.equal(
          tokenSale.totalIgnited
          .mul(10000-settings.ethBuyBP).div(10000)
        );
      });
      it("should set baseTokenLidPool to insurance token balance", async function() {
        const token = IERC20.attach(tokenInsurance.deployed);
        const balance = await token.balanceOf(liftoffInsurance.address);
        expect(tokenInsurance.baseTokenLidPool).to.equal(balance);
      });
    });
    describe("redeem", function() {
      let token;
      before(async function() {
        await liftoffEngine.claimReward(tokenSaleId.value, ignitor1.address);
        await liftoffEngine.claimReward(tokenSaleId.value, ignitor2.address);
        await liftoffEngine.claimReward(tokenSaleId.value, ignitor3.address);
        token = IERC20.attach(tokenInsurance.deployed);
        await token.connect(ignitor1).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
        await token.connect(ignitor2).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
        await token.connect(ignitor3).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
      })
      it("should refund all deposited eth minus base fee when all tokens redeemed", async function() {
        const tokenBalance = await token.balanceOf(ignitor1.address);
        await liftoffInsurance.connect(ignitor1).redeem(tokenSaleId.value, tokenBalance);
        const xethBalance = await xEth.balanceOf(ignitor1.address);
        const expectedRedeemValue = ethers.utils.parseEther("300")
          .mul(10000-settings.baseFeeBP)
          .div(10000)
        expect(xethBalance).to.be.lt(expectedRedeemValue);
        expect(xethBalance).to.be.gt(expectedRedeemValue.sub(100));
      });
      it("should refund all deposited eth minus base fee when all tokens redeemed in 2 parts", async function() {
        let tokenBalance = await token.balanceOf(ignitor2.address);
        await liftoffInsurance.connect(ignitor2).redeem(tokenSaleId.value, tokenBalance.div(2));
        tokenBalance = await token.balanceOf(ignitor2.address);
        await liftoffInsurance.connect(ignitor2).redeem(tokenSaleId.value, tokenBalance);
        const xethBalance = await xEth.balanceOf(ignitor2.address);
        const expectedRedeemValue = ethers.utils.parseEther("200")
          .mul(10000-settings.baseFeeBP)
          .div(10000)
        expect(xethBalance).to.be.lt(expectedRedeemValue);
        expect(xethBalance).to.be.gt(expectedRedeemValue.sub(100));
      });
      it("should trigger unwind if all redeemed xeth is greater than baseXEth", async function() {
        let tokenBalance = await token.balanceOf(ignitor3.address);
        await liftoffInsurance.connect(ignitor3).redeem(tokenSaleId.value, tokenBalance.div(2));
        tokenBalance = await token.balanceOf(ignitor3.address);
        await liftoffInsurance.connect(ignitor3).redeem(tokenSaleId.value, tokenBalance);
        const xethBalance = await xEth.balanceOf(ignitor3.address);
        const tokenInsuranceOthers = await liftoffInsurance.getTokenInsuranceOthers(tokenSaleId.value);
        const expectedRedeemValue = ethers.utils.parseEther("500")
          .mul(10000-settings.baseFeeBP)
          .div(10000)
        expect(xethBalance).to.be.lt(expectedRedeemValue);
        expect(xethBalance).to.be.gt(expectedRedeemValue.sub(100));
        expect(tokenInsuranceOthers.isUnwound).to.be.true;
      });
    });
    describe("claim", function() {
      before(async function() {
        const currentTime = await time.latest();
      await liftoffEngine.launchToken(
        currentTime.toNumber() + time.duration.hours(1).toNumber(),
        currentTime.toNumber() + time.duration.days(7).toNumber(),
        ether("50").toString(),
        ether("100").toString(),
        ether("1000").toString(),
        "TestToken2",
        "TKN2",
        projectDev.address
      );
      await time.increase(
        time.duration.days(1)
      );
      await time.advanceBlock();

      await liftoffEngine.connect(ignitor1).igniteEth(
        1,
          { value: ether("30").toString() }
      );
      await liftoffEngine.connect(ignitor2).igniteEth(
        1,
          { value: ether("20").toString() }
      );
      await liftoffEngine.connect(ignitor3).igniteEth(
        1,
          { value: ether("60").toString() }
      );
      await time.increase(
        time.duration.days(6)
      );
      await time.advanceBlock();
      await liftoffEngine.spark(1);
      await liftoffInsurance.createInsurance(1);
      await liftoffEngine.claimReward(1, ignitor1.address);
      await liftoffEngine.claimReward(1, ignitor2.address);
      await liftoffEngine.claimReward(1, ignitor3.address);
      });
      it("Should claim base fee, even if unwound",async function() {
        await liftoffInsurance.claim(0);
        const treasuryBalance =  await xEth.balanceOf(lidTreasury.address);
        expect(
          treasuryBalance
        ).to.eq(
          ethers.utils.parseEther("1000").mul(settings.baseFeeBP-30).div(10000)
        );
        expect(treasuryBalance).to.be.gt(ethers.utils.parseEther("10"));
        expect(treasuryBalance).to.be.lt(ethers.utils.parseEther("100"));
      });
      it("Should revert if unwound and not claiming base fee",async function() {
        await expect(
          liftoffInsurance.claim(0)
        ).to.be.revertedWith("Token insurance is unwound.")
      });
      it("Should revert if not unwound an base fee already claimed", async function() {
        await liftoffInsurance.claim(1);
        await expect(liftoffInsurance.claim(1)).to.be.revertedWith("Cannot claim until after first cycle ends.");
      });
    });
  });
  describe("State: Insurance Cycle 1", function() {
    let token;
    before(async function() {
      token = IERC20.attach(
          (
            await liftoffInsurance.getTokenInsuranceOthers(1)
          ).deployed
        );
      await token.connect(ignitor1).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
      await token.connect(ignitor2).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
      await token.connect(ignitor3).approve(liftoffInsurance.address, ethers.constants.MaxUint256);
      await time.increase(
        time.duration.days(7)
      );
      await time.advanceBlock();
    });
    describe("redeem", function() {
      it("Should revert if exceeds base eth, instead of unwind", async function() {
        const tokenBalance1 = await token.balanceOf(ignitor1.address);
        const tokenBalance2 = await token.balanceOf(ignitor2.address);
        const tokenBalance3 = await token.balanceOf(ignitor3.address);
        await liftoffInsurance.connect(ignitor1).redeem(1,tokenBalance1);
        await expect(
          liftoffInsurance.connect(ignitor2).redeem(1,tokenBalance2)
        ).to.be.revertedWith("Redeem request exceeds available insurance.");
      });
    });
    describe("claim", function() {
      it("Should distribute xeth and xxx to lidpoolmanager, projectdev, lid treasury", async function() {
        const tokenInsurance = await liftoffInsurance.getTokenInsuranceUints(1);
        const totalMaxClaim = tokenInsurance.totalIgnited.sub(tokenInsurance.redeemedXEth)
        let xethLidTrsrInitial = await xEth.balanceOf(lidTreasury.address);
        await liftoffInsurance.claim(1)
        let xethPoolBal = await xEth.balanceOf(lidPoolManager.address);
        let xethProjDev = await xEth.balanceOf(projectDev.address);
        let xethLidTrsr = await xEth.balanceOf(lidTreasury.address);
        let xethtrsrDlt = xethLidTrsr.sub(xethLidTrsrInitial);
        expect(xethProjDev).to.be.bignumber.gt(ether("2.4").toString());
        expect(xethProjDev).to.be.bignumber.lt(ether("2.5").toString());
        expect(xethProjDev).to.be.bignumber.eq(
          totalMaxClaim.mul(settings.projectDevBP).div(10000).div(10)
        );
        expect(xethtrsrDlt).to.be.bignumber.gt(ether("0.45").toString());
        expect(xethtrsrDlt).to.be.bignumber.lt(ether("0.46").toString());
        expect(xethtrsrDlt).to.be.bignumber.eq(
          totalMaxClaim.mul(settings.mainFeeBP).div(10000).div(10)
        );
        expect(xethPoolBal).to.be.bignumber.gt(ether("1.6").toString());
        expect(xethPoolBal).to.be.bignumber.lt(ether("1.7").toString());
        expect(xethPoolBal).to.be.bignumber.eq(
          totalMaxClaim.mul(settings.lidPoolBP).div(10000).div(10)
        );
      });
    });
  });
});
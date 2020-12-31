const chai = require('chai');
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ether, time } = require("@openzeppelin/test-helpers");
const { UniswapDeployAsync } = require("../tools/UniswapDeployAsync");
const { XLockDeployAsync } = require("../tools/XLockDeployAsync");
const loadJsonFile = require('load-json-file');
const settings = loadJsonFile.sync("./scripts/settings.json").networks.hardhat;

chai.use(solidity);

describe('LiftoffEngine', function () {
  let liftoffSettings, liftoffEngine;
  let liftoffRegistration, sweepReceiver, projectDev, ignitor1, ignitor2, ignitor3;
  let tokenSaleId;

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
    describe("launchToken", function () {  
      it("Should revert if sender is not Launcher", async function () {
        const currentTime = await time.latest();
        const contract = liftoffEngine.connect(projectDev);
        await expect(
          contract.launchToken(
            currentTime.toNumber() + time.duration.hours(1).toNumber(),
            currentTime.toNumber() + time.duration.days(7).toNumber(),
            ether("1000").toString(),
            ether("3000").toString(),
            ether("10000").toString(),
            "TestToken",
            "TKN",
            projectDev.address
          )
        ).to.be.revertedWith("Sender must be LiftoffRegistration");
      })

      it("Should revert if endTime is before startTime", async function () {
        const currentTime = await time.latest();
        const contract = liftoffEngine.connect(liftoffRegistration);
        await expect(
          contract.launchToken(
            currentTime.toNumber() + time.duration.days(7).toNumber(),
            currentTime.toNumber() + time.duration.hours(1).toNumber(),
            ether("1000").toString(),
            ether("3000").toString(),
            ether("10000").toString(),
            "TestToken",
            "TKN",
            projectDev.address
          )
        ).to.be.revertedWith("Must end after start");
      })

      it("Should revert if startTime is before now", async function () {
        const currentTime = await time.latest();
        const contract = liftoffEngine.connect(liftoffRegistration);
        await expect(
          contract.launchToken(
            currentTime.toNumber() - time.duration.hours(1).toNumber(),
            currentTime.toNumber() + time.duration.days(7).toNumber(),
            ether("1000").toString(),
            ether("3000").toString(),
            ether("10000").toString(),
            "TestToken",
            "TKN",
            projectDev.address
          )
        ).to.be.revertedWith("Must start in the future");
      })
      
      it("Should revert if Hardcap is less than SoftCap", async function () {
        const currentTime = await time.latest();
        const contract = liftoffEngine.connect(liftoffRegistration);
        await expect(
          contract.launchToken(
            currentTime.toNumber() + time.duration.days(1).toNumber(),
            currentTime.toNumber() + time.duration.days(7).toNumber(),
            ether("3000").toString(),
            ether("1000").toString(),
            ether("10000").toString(),
            "TestToken",
            "TKN",
            projectDev.address
          )
        ).to.be.revertedWith("Hardcap must be at least softCap");
      })
    })
  })

  describe("State: Before Liftoff Launch",function() {
    before(async function(){
      const currentTime = await time.latest()
      tokenSaleId = await liftoffEngine.launchToken(
        currentTime.toNumber() + time.duration.hours(1).toNumber(),
        currentTime.toNumber() + time.duration.days(7).toNumber(),
        ether("1000").toString(),
        ether("3000").toString(),
        ether("10000").toString(),
        "TestToken",
        "TKN",
        projectDev.address
      )
    })

    describe("igniteEth", function () {
      it("Should revert if token not started yet", async function () {
        await expect(
          liftoffEngine.igniteEth(tokenSaleId.value)
        ).to.be.revertedWith("Not igniting.");
      })
    })

    describe("spark", function () {
      it("Should revert if token not started yet", async function () {
        await expect(
          liftoffEngine.spark(tokenSaleId.value)
        ).to.be.revertedWith("Not spark ready");
      })
    })

    describe("claimReward", function() {
      it("Should revert if token not started yet", async function () {
        await expect(
          liftoffEngine.claimReward(tokenSaleId.value, ignitor1.address)
        ).to.be.revertedWith("Token must have been sparked.");
      })
    })
  })

  describe("State: Pre Spark",function() {
    before(async function () {
      //Advance forward 1 day into post launch but pre spark period
      await time.increase(
        time.duration.days(1)
      );
      await time.advanceBlock();
    })

    describe("spark", function () {
      it("Should revert", async function () {
        await expect(
          liftoffEngine.spark(tokenSaleId.value)
        ).to.be.revertedWith("Not spark ready");
      })
    })
    
    describe("igniteEth", function () {
      it("Should ignite", async function () {
        // first ignitor
        let contract = liftoffEngine.connect(ignitor1);
        await contract.igniteEth(
          tokenSaleId.value,
          { value: ether("300").toString() }
        );

        let tokenInfo = await liftoffEngine.getTokenSale(tokenSaleId.value);
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("300").toString());

        // second ignitor
        contract = liftoffEngine.connect(ignitor2);
        await contract.igniteEth(
          tokenSaleId.value,
          { value: ether("200").toString() }
        );

        tokenInfo = await liftoffEngine.getTokenSale(tokenSaleId.value);
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("500").toString());

        // third ignitor
        contract = liftoffEngine.connect(ignitor3);
        await contract.igniteEth(
          tokenSaleId.value,
          { value: ether("500").toString() }
        );

        tokenInfo = await liftoffEngine.getTokenSale(tokenSaleId.value);
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("1000").toString());
      })
    })

    describe("claimReward", function() {
      it("Should revert if token not sparked yet", async function () {
        await expect(
          liftoffEngine.claimReward(tokenSaleId.value, ignitor1.address)
        ).to.be.revertedWith("Token must have been sparked.");
      })
    })

    describe("claimRefund", function() {
      it("Should revert if it already reached to softcap", async function () {
        await expect(
          liftoffEngine.claimRefund(tokenSaleId.value, ignitor1.address)
        ).to.be.revertedWith("Not refunding");
      })
    })
  })

   describe("State: Post Spark", function () {
     let deployed;
     before(async function(){
       await time.increase(
         time.duration.days(6)
       );
       await time.advanceBlock();
       await liftoffEngine.spark(tokenSaleId.value);
     })
     describe("spark", function () {
       it("Should revert if token already sparked", async function () {
         await expect(
           liftoffEngine.spark(tokenSaleId.value)
         ).to.be.revertedWith("Not spark ready");
       })
     })

     describe("getTokenSaleForInsurance", function() {
       it("Should get token sale info for insurance", async function () {
         let tokenInfo = await liftoffEngine.getTokenSaleForInsurance(tokenSaleId.value);
         deployed = tokenInfo.deployed.toString();
         expect(tokenInfo.totalIgnited.toString()).to.equal(ether("1000").toString());
         expect(tokenInfo.pair.toString()).to.be.properAddress;
         expect(tokenInfo.deployed.toString()).to.be.properAddress;
         expect(tokenInfo.rewardSupply.toString()).to.be.bignumber.above(ether("4353").toString());
         expect(tokenInfo.rewardSupply.toString()).to.be.bignumber.below(ether("4354").toString());
       })
     })

    describe("claimReward", function () {
      it("Should claim rewards", async function () {
        await liftoffEngine.claimReward(
          tokenSaleId.value,
          ignitor1.address
        );
        // ignitor1 ignited 300ETH of total 1000ETH
        // ignite1's rewards = 300 * rewardSupply / 1000
        const token = await ethers.getContractAt("ERC20Standard", deployed);
        expect((await token.balanceOf(ignitor1.address)).toString()).to.be.bignumber.above(ether("1305").toString());
        expect((await token.balanceOf(ignitor1.address)).toString()).to.be.bignumber.below(ether("1306").toString());
      })

      it("revert if ignitor already claimed", async function () {
        await expect(
          liftoffEngine.claimReward(tokenSaleId.value, ignitor1.address)
        ).to.be.revertedWith("Ignitor has already claimed");
      })
    })

     describe("setLiftoffSettings", function() {
       it("Should revert if caller is not the owner", async function () {
         let contract = liftoffEngine.connect(ignitor1);
         await expect(
           contract.setLiftoffSettings(ignitor1.address)
         ).to.be.revertedWith("Ownable: caller is not the owner");
       })
     })
   })

  describe("Refund",function() {
    before(async function(){
      const currentTime = await time.latest()
      tokenSaleId = await liftoffEngine.launchToken(
        currentTime.toNumber() + time.duration.hours(1).toNumber(),
        currentTime.toNumber() + time.duration.days(1).toNumber(),
        ether("1000").toString(),
        ether("3000").toString(),
        ether("10000").toString(),
        "TestToken",
        "TKN",
        projectDev.address
      );
      await time.increase(
        time.duration.hours(1)
      );
      await time.advanceBlock();
    })

    describe("ignite", function () {
      it("Should ignite", async function () {
        let contract = liftoffEngine.connect(ignitor1);
        await contract.igniteEth(
          1,
          { value: ether("300").toString() }
        );


        let tokenInfo = await liftoffEngine.getTokenSale(1);
        expect(tokenInfo.totalIgnited.toString()).to.equal(ether("300").toString());
      })
    })

    describe("claimRefund", function() {
      it("Should revert if it is before endTime", async function () {
        await expect(
          liftoffEngine.claimRefund(1, ignitor1.address)
        ).to.be.revertedWith("Not refunding");
      })

      it("Should refund", async function () {
        await time.increase(
          time.duration.days(1)
        );
        await time.advanceBlock();
        await liftoffEngine.claimRefund(1, ignitor1.address);
        expect((await xEth.balanceOf(ignitor1.address)).toString()).to.equal(ether("300").toString());
      })

      it("revert if ignitor already refunded", async function () {
        await expect(
          liftoffEngine.claimRefund(1, ignitor1.address)
        ).to.be.revertedWith("Ignitor has already refunded");
      })
    })
  })
});
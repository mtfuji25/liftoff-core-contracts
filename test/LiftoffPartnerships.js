const chai = require('chai');
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ether, time } = require("@openzeppelin/test-helpers");
const { UniswapDeployAsync } = require("../tools/UniswapDeployAsync");
const { XLockDeployAsync } = require("../tools/XLockDeployAsync");
const loadJsonFile = require('load-json-file');
const settings = loadJsonFile.sync("./scripts/settings.json").networks.hardhat;

chai.use(solidity);

describe('LiftoffPartnerships', function () {
  let liftoffSettings, liftoffEngine, liftoffPartnerships;
  let liftoffRegistration, sweepReceiver, projectDev, partner1, partner2;
  let tokenSaleId;

  before(async function () {
    const accounts = await ethers.getSigners();
    liftoffRegistration = accounts[0];
    sweepReceiver = accounts[1];
    projectDev = accounts[2];
    lidTreasury = accounts[3];
    lidPoolManager = accounts[4];
    partner1 = accounts[5];
    partner2 = accounts[6];

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

    LiftoffPartnerships = await ethers.getContractFactory("LiftoffPartnerships");
    liftoffPartnerships = await upgrades.deployProxy(LiftoffPartnerships, [liftoffSettings.address], { unsafeAllowCustomTypes: true });
    await liftoffPartnerships.deployed();

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
      liftoffPartnerships.address,
      xEth.address,
      xLocker.address,
      uniswapV2Router02.address,
      lidTreasury.address,
      lidPoolManager.address
    );

  });

  describe("State: Before Token Sale Start",function() {
    before(async function(){
      const currentTime = await time.latest()
      tokenSaleId = await liftoffEngine.launchToken(
        currentTime.toNumber() + time.duration.hours(1).toNumber(),
        currentTime.toNumber() + time.duration.days(7).toNumber(),
        ether("500").toString(),
        ether("1000").toString(),
        ether("10000").toString(),
        "TestToken",
        "TKN",
        projectDev.address
      )
    })

    describe("setPartner", function () {
      it("Should revert if caller is not the owner", async function () {
        let contract = liftoffPartnerships.connect(projectDev);
         await expect(
           contract.setPartner(0, partner1.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
         ).to.be.revertedWith("Ownable: caller is not the owner");
       })

      it("Success", async function () {
        await liftoffPartnerships.setPartner(0, partner1.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
        await liftoffPartnerships.setPartner(1, partner2.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
      })

      it("Should revert if partner id is bigger than totalPartnerControllers", async function () {
        await expect(
          liftoffPartnerships.setPartner(3, partner2.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
        ).to.be.revertedWith("Must increment partnerId.");
      })

      it("Success", async function () {
        const ADDRESS0x0 = "0x0000000000000000000000000000000000000000";
        await liftoffPartnerships.setPartner(2, partner2.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
        await liftoffPartnerships.setPartner(2, ADDRESS0x0, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
      })
    })

    describe("requestPartnership", function () {
      it("Should revert if caller is not the owner or token sale dev", async function () {
        let contract = liftoffPartnerships.connect(partner1);
         await expect(
           contract.requestPartnership(0, tokenSaleId.value, 100)
         ).to.be.revertedWith("Sender must be Owner or TokenSaleDev");
      })

      it("Success", async function () {
        let contract = liftoffPartnerships.connect(projectDev);
        await contract.requestPartnership(0, tokenSaleId.value, 100)
        await liftoffPartnerships.requestPartnership(1, tokenSaleId.value, 100)
      })
    })

    describe("acceptPartnership", function() {
      it("Should revert if caller is not the owner or partner controller", async function () {
        let contract = liftoffPartnerships.connect(projectDev);
         await expect(
           contract.acceptPartnership(tokenSaleId.value, 0)
         ).to.be.revertedWith("Sender must be Owner or PartnerController");
      })

      it("Success", async function () {
        let contract = liftoffPartnerships.connect(partner1);
        await contract.acceptPartnership(tokenSaleId.value, 0)
        await liftoffPartnerships.acceptPartnership(tokenSaleId.value, 1)
      })
    })

    describe("getTotalBP", function() {
      it("Should get totalBP", async function () {
        let totalBP = await liftoffPartnerships.getTotalBP(tokenSaleId.value);
        expect(totalBP.toString()).to.equal("200");
      })
    })

    describe("getTokenSalePartnerships", function() {
      it("Should get totalPartnerships and totalBPForPartnerships", async function () {
        let result = await liftoffPartnerships.getTokenSalePartnerships(tokenSaleId.value);
        expect(result.totalPartnerships.toString()).to.equal("2");
        expect(result.totalBPForPartnerships.toString()).to.equal("200");
      })
    })

    describe("cancelPartnership", function() {
      it("Should revert if caller is not the owner or partner controller", async function () {
        let contract = liftoffPartnerships.connect(projectDev);
         await expect(
           contract.cancelPartnership(tokenSaleId.value, 0)
         ).to.be.revertedWith("Sender must be Owner or PartnerController");
      })

      it("Success", async function () {
        let contract = liftoffPartnerships.connect(partner1);
        await contract.cancelPartnership(tokenSaleId.value, 0)
        await liftoffPartnerships.cancelPartnership(tokenSaleId.value, 1)
      })
    })
  })

  describe("State: After Token Sale Start",function() {
    before(async function () {
      //Advance forward 1 day into post launch
      await time.increase(
        time.duration.days(1)
      );
      await time.advanceBlock();
    })

    describe("setPartner", function () {
      it("Success", async function () {
        await liftoffPartnerships.setPartner(3, partner1.address, "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t")
      })
    })

    describe("requestPartnership", function () {
      it("Should revert if sale already started", async function () {
         await expect(
          liftoffPartnerships.requestPartnership(0, tokenSaleId.value, 100)
         ).to.be.revertedWith("Sale already started.");
      })
    })

    describe("acceptPartnership", function() {
      it("Should revert if sale already started", async function () {
        await expect(
         liftoffPartnerships.acceptPartnership(tokenSaleId.value, 1)
        ).to.be.revertedWith("Sale already started.");
     })
    })

    describe("cancelPartnership", function() {
      it("Should revert if sale already started", async function () {
        await expect(
         liftoffPartnerships.cancelPartnership(tokenSaleId.value, 1)
        ).to.be.revertedWith("Sale already started.");
     })
    })
  })
});
const chai = require('chai');
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ether, time } = require("@openzeppelin/test-helpers");
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
    )

    await liftoffSettings.setAllAddresses(
      liftoffInsurance.address,
      liftoffRegistration.address,
      liftoffEngine.address,
      xEth.address,
      xLocker.address,
      uniswapV2Router02.address,
      lidTreasury.address,
      lidPoolManager.address
    )
  })

  describe("Stateless", function() {
    describe("register", function() {
      it("should revert if sender is not liftoffEngine", async function() {
        await expect(
          liftoffInsurance.register(0)
        ).to.be.revertedWith("Sender must be Liftoff Engine")
      })
    })
    describe("redeem", function() {
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.redeem(0,0)
        ).to.be.revertedWith("Insurance not initialized")
      })
    });
    describe("claim", function() {
      it("should revert if insurance is not initialized for tokenSaleId", async function() {
        await expect(
          liftoffInsurance.claim(0)
        ).to.be.revertedWith("Insurance not initialized")
      })
    });
    /*describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Registered", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Initialized", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Cycle 1", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Cycle 5", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Cycle 11", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
  describe("State: Insurance Exhausted", function() {
    /*describe("register", function() {

    })
    describe("redeem", function() {

    });
    describe("claim", function() {

    });
    describe("createInsurance", function() {

    });
    describe("isInsuranceExhausted", function() {

    });
    describe("canCreateInsurance", function() {

    });
    describe("getRedeemValue", function() {

    });
    describe("getTotalTokenClaimable", function() {

    });
    describe("getTotalXethClaimable", function() {

    });*/
  })
});
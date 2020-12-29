const chai = require('chai');
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ether, time } = require("@openzeppelin/test-helpers");
const { UniswapDeployAsync } = require("../tools/UniswapDeployAsync");

chai.use(solidity);

describe('LiftoffEngine', function () {
  let liftoffSettings, liftoffEngine, xeth, xlocker;
  let liftoffRegistration, sweepReceiver, projectDev, claimAddress, ignitor1, ignitor2, ignitor3;
  let tokenSaleId;

  before(async function () {
    const accounts = await ethers.getSigners();
    liftoffRegistration = accounts[0];
    sweepReceiver = accounts[1];
    projectDev = accounts[2];
    claimAddress = accounts[3];
    ignitor1 = accounts[4];
    ignitor2 = accounts[5];
    ignitor3 = accounts[6];

    LiftoffSettings = await ethers.getContractFactory("LiftoffSettings");
    liftoffSettings = await upgrades.deployProxy(LiftoffSettings, []);
    await liftoffSettings.deployed();

    await liftoffSettings.setLiftoffRegistration(liftoffRegistration.address);

    LiftoffInsurance = await ethers.getContractFactory("LiftoffInsurance");
    liftoffInsurance = await upgrades.deployProxy(LiftoffInsurance, [liftoffSettings.address], { unsafeAllowCustomTypes: true });
    await liftoffInsurance.deployed();

    await liftoffSettings.setLiftoffInsurance(liftoffInsurance.address);
    
    LiftoffEngine = await ethers.getContractFactory("LiftoffEngine");
    liftoffEngine = await upgrades.deployProxy(LiftoffEngine, [liftoffSettings.address], { unsafeAllowCustomTypes: true });
    await liftoffEngine.deployed();

    await liftoffSettings.setLiftoffEngine(liftoffEngine.address);

    const { uniswapV2Router02, uniswapV2Factory } = await UniswapDeployAsync(ethers);
    await liftoffSettings.setUniswapRouter(uniswapV2Router02.address);

    Xeth = await ethers.getContractFactory("XETH");
    xeth = await Xeth.deploy();
    await xeth.deployed();

    Xlocker = await ethers.getContractFactory("XLOCKER");
    xlocker = await upgrades.deployProxy(Xlocker, [xeth.address, sweepReceiver.address, ether("1000000").toString(), ether("1000000000000").toString(), uniswapV2Router02.address, uniswapV2Factory.address]);
    await xlocker.deployed();

    await xeth.grantXethLockerRole(xlocker.address);

    await liftoffSettings.setXEth(xeth.address);
    await liftoffSettings.setXLocker(xlocker.address);
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
          liftoffEngine.claimReward(tokenSaleId.value, claimAddress.address)
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
      it("Should revert if token not started yet", async function () {
        await expect(
          liftoffEngine.claimReward(tokenSaleId.value, claimAddress.address)
        ).to.be.revertedWith("Token must have been sparked.");
      })
    })
  })

  // describe("State: Post Spark", function () {
  //   before(async function(){
  //     await time.increase(
  //       time.duration.days(6)
  //     );
  //     await time.advanceBlock();
  //     await liftoffEngine.spark(tokenSaleId.value);
  //   })

  //   describe("spark", function () {
  //     it("Should revert if token already sparked", async function () {
  //       await expect(
  //         liftoffEngine.spark(tokenSaleId.value)
  //       ).to.be.revertedWith("Not spark ready");
  //     })
  //   })

  //   describe("igniteEth", function () {
  //     it("Should ignite", async function () {
  //       let contract = liftoffEngine.connect(ignitor1);
  //       await contract.igniteEth(
  //         tokenSaleId.value,
  //         { value: ether("200").toString() }
  //       );

  //       let tokenInfo = await liftoffEngine.getTokenSale(tokenSaleId.value);
  //       expect(tokenInfo.totalIgnited.toString()).to.equal(ether("1200").toString());
  //     })
  //   })

  //   describe("getTokenSaleForInsurance", function() {
  //     it("Should get ignitor balance", async function () {
  //       let tokenInfo = await liftoffEngine.getTokenSaleForInsurance(tokenSaleId.value);
  //       console.log(222, tokenInfo.deployed)
  //       expect(tokenInfo.totalIgnited.toString()).to.equal(ether("1200").toString());
  //       expect(tokenInfo.deployed.toString()).to.be.properAddress;
  //     })
  //   })

  //   describe("setLiftoffSettings", function() {
  //     it("Should revert if caller is not the owner", async function () {
  //       let contract = liftoffEngine.connect(ignitor1);
  //       await expect(
  //         contract.setLiftoffSettings(ignitor1.address)
  //       ).to.be.revertedWith("Ownable: caller is not the owner");
  //     })
  //   })
  // })
});
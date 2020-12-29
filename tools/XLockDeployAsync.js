//USAGE:
/*
let {
  xEth, xLocker
} = await XLockDeployAsync(ethers, sweepReceiver, uniswapV2Factory, uniswapV2Router02 );
*/
const { ether } = require("@openzeppelin/test-helpers");

const ADDRESS0x0 = "0x0000000000000000000000000000000000000000";

module.exports.XLockDeployAsync = async (ethers, sweepReceiver, uniswapV2Factory, uniswapV2Router02) => {
  XEth = await ethers.getContractFactory("XETH");
  xEth = await XEth.deploy();
  await xEth.deployed();

  XLocker = await ethers.getContractFactory("XLOCKER");
  xLocker = await upgrades.deployProxy(XLocker, [xEth.address, sweepReceiver.address, ether("1000000").toString(), ether("1000000000000").toString(), uniswapV2Router02.address, uniswapV2Factory.address]);
  await xLocker.deployed();

  await xEth.grantXethLockerRole(xLocker.address);

  return {
    xEth, xLocker
  }
}
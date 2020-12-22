//USAGE:
/*
let {
  weth, uniswapV2Factory, uniswapV2Router02
} = await UniswapDeployAsync(ethers);
*/

const ADDRESS0x0 = "0x0000000000000000000000000000000000000000";

module.exports.UniswapDeployAsync = async (ethers) => {
  const Weth = await ethers.getContractFactory("WETH9");
  const weth = await Weth.deploy();
  await weth.deployed();

  const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
  const uniswapV2Factory = await UniswapV2Factory.deploy(ADDRESS0x0);
  await uniswapV2Factory.deployed();
  
  const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
  const uniswapV2Router02 = await UniswapV2Router02.deploy(
    uniswapV2Factory.address,
    weth.address
  );
  await uniswapV2Router02.deployed();

  return {
    weth, uniswapV2Factory, uniswapV2Router02
  }
}
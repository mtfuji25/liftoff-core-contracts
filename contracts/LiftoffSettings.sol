pragma solidity 0.5.16;

import "./interfaces/ILiftoffSettings.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffSettings is ILiftoffSettings, Initializable, Ownable {

  uint private ethXLockBP;
  uint private ethBuyBP;
  uint private tokenUserBP;
  
  uint private ignitePeriod;
  uint private baseFee;
  uint private insurancePeriod;

  address private liftoffInsurance;
  address private liftoffLauncher;
  address private liftoffEngine;
  address private xEth;
  address private xLocker;
  address private uniswapRouter;

  function initialize(
    address _liftoffGovernance,
    uint _ethXLockBP,
    uint _ethBuyBP,
    uint _tokenUserBP
  ) external initializer {
    Ownable.initialize(_liftoffGovernance);
    ethXLockBP = _ethXLockBP;
    ethBuyBP = _ethBuyBP;
    tokenUserBP = _tokenUserBP;
  }

  function setEthXLockBP(uint _val) external onlyOwner {
    ethXLockBP = _val;
  }
  function getEthXLockBP() external view returns (uint) {
    return ethXLockBP;
  }
  
  function setEthBuyBP(uint _val) external onlyOwner {
    ethBuyBP = _val;
  }
  function getEthBuyBP() external view returns (uint) {
    return ethBuyBP;
  }
  
  function setTokenUserBP(uint _val) external onlyOwner {
    tokenUserBP = _val;
  }
  function getTokenUserBP() external view returns (uint) {
    return tokenUserBP;
  }
  
  function setLiftoffInsurance(address _val) external onlyOwner {
    liftoffInsurance = _val;
  }
  function getLiftoffInsurance() external view returns (address) {
    return liftoffInsurance;
  }
  
  function setLiftoffLauncher(address _val) external onlyOwner {
    liftoffLauncher = _val;
  }
  function getLiftoffLauncher() external view returns (address) {
    return liftoffLauncher;
  }

  function setLiftoffEngine(address _val) external onlyOwner {
    liftoffEngine = _val;
  }
  function getLiftoffEngine() external view returns (address){
    return liftoffEngine;
  }
  
  function setXEth(address _val) external onlyOwner {
    xEth = _val;
  }
  function getXEth() external view returns (address) {
    return xEth;
  }
  
  function setXLocker(address _val) external onlyOwner {
    xLocker = _val;
  }
  function getXLocker() external view returns (address) {
    return xLocker;
  }
  
  function setUniswapRouter(address _val) external onlyOwner {
    uniswapRouter = _val;
  }
  function getUniswapRouter() external view returns (address) {
    return uniswapRouter;
  }
  
  function setIgnitePeriod(uint _val) external onlyOwner {
    ignitePeriod = _val;
  }
  function getIgnitePeriod() external view returns (uint) {
    return ignitePeriod;
  }
  
  function setBaseFee(uint _val) external onlyOwner {
    baseFee = _val;
  }
  function getBaseFee() external view returns (uint) {
    return baseFee;
  }
  
  function setInsurancePeriod(uint _val) external onlyOwner {
    insurancePeriod = _val;
  }
  function getInsurancePeriod() external view returns (uint) {
    return insurancePeriod;
  }

}
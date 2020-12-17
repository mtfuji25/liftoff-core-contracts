pragma solidity 0.5.16;

import "./interfaces/ILiftoffSettings.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffSettings is ILiftoffSettings, Initializable, Ownable {

  uint private ethXLockBP;
  uint private tokenUserBP;
  
  uint private ignitePeriod;
  uint private insurancePeriod;
  
  uint private ethBuyBP;
  uint private baseFee;
  uint private projectDevBP;
  uint private mainFeeBP;
  uint private lidPoolBP;

  address private liftoffInsurance;
  address private liftoffLauncher;
  address private liftoffEngine;
  address private xEth;
  address private xLocker;
  address private uniswapRouter;

  address private lidTreasury;
  address private lidPoolManager;

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
  
  function setInsurancePeriod(uint _val) external onlyOwner {
    insurancePeriod = _val;
  }
  function getInsurancePeriod() external view returns (uint) {
    return insurancePeriod;
  }
  
  function setLidTreasury(address _val) external onlyOwner {
    lidTreasury = _val;
  }
  function getLidTreasury() external view returns (address) {
    return lidTreasury;
  }

  function setLidPoolManager(address _val) external onlyOwner {
    lidPoolManager = _val;
  }
  function getLidPoolManager() external view returns (address) {
    return lidPoolManager;
  }

  function setXethBP(
    uint _baseFeeBP,
    uint _ethBuyBP,
    uint _projectDevBP,
    uint _mainFeeBP,
    uint _lidPoolBP
  ) external {
    require(
      _baseFeeBP
      + _ethBuyBP 
      + _projectDevBP
      + _mainFeeBP
      + _lidPoolBP
      == 10000,
      "Must allocate 100% of eth raised"
    );
    baseFee = _baseFeeBP;
    ethBuyBP = _ethBuyBP;
    projectDevBP = _projectDevBP;
    mainFeeBP = _mainFeeBP;
    lidPoolBP = _lidPoolBP;
  }
  function getBaseFeeBP() external view returns (uint) {
    return baseFee;
  }
  function getEthBuyBP() external view returns (uint) {
    return ethBuyBP;
  }
  function getProjectDevBP() external view returns (uint){
    return projectDevBP;
  }
  function getMainFeeBP() external view returns (uint){
    return mainFeeBP;
  }
  function getLidPoolBP() external view returns (uint){
    return lidPoolBP;
  }

}
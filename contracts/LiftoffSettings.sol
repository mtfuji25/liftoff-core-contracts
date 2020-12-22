pragma solidity =0.6.6;

import "./interfaces/ILiftoffSettings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiftoffSettings is ILiftoffSettings, Initializable, OwnableUpgradeable {

  uint private ethXLockBP;
  uint private tokenUserBP;
  
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

  event LogEthXLockBP(uint ethXLockBP);
  event LogTokenUserBP(uint tokenUserBP);
  event LogInsurancePeriod(uint insurancePeriod);
  event LogXethBP(uint baseFee, uint ethBuyBP, uint projectDevBP, uint mainFeeBP, uint lidPoolBP);
  event LogLidTreasury(address lidTreasury);
  event LogLidPoolManager(address lidPoolManager);
  event LogLiftoffInsurance(address liftoffInsurance);
  event LogLiftoffLauncher(address liftoffLauncher);
  event LogLiftoffEngine(address liftoffEngine);
  event LogXEth(address xEth);
  event LogXLocker(address xLocker);
  event LogUniswapRouter(address uniswapRouter);

  function initialize(
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
  }

  function setEthXLockBP(uint _val) external override onlyOwner {
    ethXLockBP = _val;

    emit LogEthXLockBP(ethXLockBP);
  }
  function getEthXLockBP() external override  view returns (uint) {
    return ethXLockBP;
  }
  
  function setTokenUserBP(uint _val) external override  onlyOwner {
    tokenUserBP = _val;

    emit LogTokenUserBP(tokenUserBP);
  }
  function getTokenUserBP() external override  view returns (uint) {
    return tokenUserBP;
  }
  
  function setLiftoffInsurance(address _val) external override onlyOwner {
    liftoffInsurance = _val;

    emit LogLiftoffInsurance(liftoffInsurance);
  }
  function getLiftoffInsurance() external override view returns (address) {
    return liftoffInsurance;
  }
  
  function setLiftoffLauncher(address _val) external override onlyOwner {
    liftoffLauncher = _val;

    emit LogLiftoffLauncher(liftoffLauncher);
  }
  function getLiftoffLauncher() external override view returns (address) {
    return liftoffLauncher;
  }

  function setLiftoffEngine(address _val) external override onlyOwner {
    liftoffEngine = _val;

    emit LogLiftoffEngine(liftoffEngine);
  }
  function getLiftoffEngine() external override view returns (address){
    return liftoffEngine;
  }
  
  function setXEth(address _val) external override onlyOwner {
    xEth = _val;

    emit LogXEth(xEth);
  }
  function getXEth() external override view returns (address) {
    return xEth;
  }
  
  function setXLocker(address _val) external override onlyOwner {
    xLocker = _val;

    emit LogXLocker(xLocker);
  }
  function getXLocker() external override view returns (address) {
    return xLocker;
  }
  
  function setUniswapRouter(address _val) external override onlyOwner {
    uniswapRouter = _val;

    emit LogUniswapRouter(uniswapRouter);
  }

  function getUniswapRouter() external override view returns (address) {
    return uniswapRouter;
  }
  
  function setInsurancePeriod(uint _val) external override onlyOwner {
    insurancePeriod = _val;

    emit LogInsurancePeriod(insurancePeriod);
  }
  function getInsurancePeriod() external override view returns (uint) {
    return insurancePeriod;
  }
  
  function setLidTreasury(address _val) external override onlyOwner {
    lidTreasury = _val;

    emit LogLidTreasury(lidTreasury);
  }
  function getLidTreasury() external override view returns (address) {
    return lidTreasury;
  }

  function setLidPoolManager(address _val) external override onlyOwner {
    lidPoolManager = _val;

    emit LogLidPoolManager(lidPoolManager);
  }
  function getLidPoolManager() external override view returns (address) {
    return lidPoolManager;
  }

  function setXethBP(
    uint _baseFeeBP,
    uint _ethBuyBP,
    uint _projectDevBP,
    uint _mainFeeBP,
    uint _lidPoolBP
  ) external override {
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

    emit LogXethBP(baseFee, ethBuyBP, projectDevBP, mainFeeBP, lidPoolBP);
  }
  function getBaseFeeBP() external override view returns (uint) {
    return baseFee;
  }
  function getEthBuyBP() external override view returns (uint) {
    return ethBuyBP;
  }
  function getProjectDevBP() external override view returns (uint){
    return projectDevBP;
  }
  function getMainFeeBP() external override view returns (uint){
    return mainFeeBP;
  }
  function getLidPoolBP() external override view returns (uint){
    return lidPoolBP;
  }

}
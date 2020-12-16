pragma solidity 0.5.16;

interface ILiftoffSettings {

  function setEthXLockBP(uint _val) external;
  function getEthXLockBP() external view returns (uint);

  function setEthBuyBP(uint _val) external;
  function getEthBuyBP() external view returns (uint);

  function setTokenUserBP(uint _val) external;
  function getTokenUserBP() external view returns (uint);

  function setLiftoffInsurance(address _val) external;
  function getLiftoffInsurance() external view returns (address);

  function setLiftoffLauncher(address _val) external;
  function getLiftoffLauncher() external view returns (address);

  function setLiftoffEngine(address _val) external;
  function getLiftoffEngine() external view returns (address);

  function setXEth(address _val) external;
  function getXEth() external view returns (address);

  function setXLocker(address _val) external;
  function getXLocker() external view returns (address);

  function setUniswapRouter(address _val) external;
  function getUniswapRouter() external view returns (address);

  function setIgnitePeriod(uint _val) external;
  function getIgnitePeriod() external view returns (uint);

  function setBaseFee(uint _val) external;
  function getBaseFee() external view returns (uint);

  function setInsurancePeriod(uint _val) external;
  function getInsurancePeriod() external view returns (uint);

}
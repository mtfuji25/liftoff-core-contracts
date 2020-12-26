pragma solidity =0.6.6;

interface ILiftoffSettings {
    function setEthXLockBP(uint256 _val) external;

    function getEthXLockBP() external view returns (uint256);

    function setTokenUserBP(uint256 _val) external;

    function getTokenUserBP() external view returns (uint256);

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

    function setInsurancePeriod(uint256 _val) external;

    function getInsurancePeriod() external view returns (uint256);

    function setLidTreasury(address _val) external;

    function getLidTreasury() external view returns (address);

    function setLidPoolManager(address _val) external;

    function getLidPoolManager() external view returns (address);

    function setXethBP(
        uint256 _baseFeeBP,
        uint256 _ethBuyBP,
        uint256 _projectDevBP,
        uint256 _mainFeeBP,
        uint256 _lidPoolBP
    ) external;

    function getBaseFeeBP() external view returns (uint256);

    function getEthBuyBP() external view returns (uint256);

    function getProjectDevBP() external view returns (uint256);

    function getMainFeeBP() external view returns (uint256);

    function getLidPoolBP() external view returns (uint256);
}

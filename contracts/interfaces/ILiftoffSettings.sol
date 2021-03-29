pragma solidity =0.6.6;

interface ILiftoffSettings {
    function setAllUints(
        uint256 _ethXLockBP,
        uint256 _tokenUserBP,
        uint256 _insurancePeriod,
        uint256 _baseFeeBP,
        uint256 _ethBuyBP,
        uint256 _projectDevBP,
        uint256 _mainFeeBP,
        uint256 _lidPoolBP,
        uint256 _airdropBP
    ) external;

    function setAllAddresses(
        address _liftoffInsurance,
        address _liftoffRegistration,
        address _liftoffEngine,
        address _liftoffPartnerships,
        address _xEth,
        address _xLocker,
        address _uniswapRouter,
        address _lidTreasury,
        address _lidPoolManager,
        address _airdropDistributor
    ) external;

    function setEthXLockBP(uint256 _val) external;

    function getEthXLockBP() external view returns (uint256);

    function setTokenUserBP(uint256 _val) external;

    function getTokenUserBP() external view returns (uint256);

    function setAirdropBP(uint256 _val) external;

    function getAirdropBP() external view returns (uint256);

    function setLiftoffInsurance(address _val) external;

    function getLiftoffInsurance() external view returns (address);

    function setLiftoffRegistration(address _val) external;

    function getLiftoffRegistration() external view returns (address);

    function setLiftoffEngine(address _val) external;

    function getLiftoffEngine() external view returns (address);

    function setLiftoffPartnerships(address _val) external;

    function getLiftoffPartnerships() external view returns (address);

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

    function setAirdropDistributor(address _val) external;

    function getAirdropDistributor() external view returns (address);

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

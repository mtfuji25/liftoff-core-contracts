pragma solidity =0.6.6;

interface ILiftoffEngine {
  function launchToken(
    uint _startTime,
    uint _endTime,
    uint _softCap,
    uint _hardCap,
    uint _totalSupply,
    string calldata _name,
    string calldata _symbol,
    address _projectDev
  ) external returns (uint tokenId);
  function igniteEth(uint _tokenSaleId) external payable;
  function ignite(uint _tokenSaleId, address _for, uint _amountXEth) external;
  function claimReward(uint _tokenSaleId, address _for) external;
  function spark(uint _tokenSaleId) external;
  function claimRefund(uint _tokenSaleId, address payable _for) external;
  function getTokenSale(uint _tokenSaleId) external view returns (
    uint startTime,
    uint endTime,
    uint softCap,
    uint hardCap,
    uint totalIgnited,
    uint totalSupply,
    uint rewardSupply,
    address projectDev,
    address deployed,
    bool isSparked
  );
  function getTokenSaleForInsurance(uint _tokenSaleId) external view returns (
    uint totalIgnited,
    uint rewardSupply,
    address projectDev,
    address deployed
  );
}
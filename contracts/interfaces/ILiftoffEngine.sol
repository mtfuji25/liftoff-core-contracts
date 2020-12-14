pragma solidity 0.5.16;
import "./ILiftoffInsurance.sol";
import "../xlock/IXeth.sol";
import "../xlock/IXLocker.sol";
import "../uniswapV2Periphery/interfaces/IUniswapV2Router01.sol";

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
}
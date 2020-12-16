pragma solidity 0.5.16;

interface ILiftoffInsurance {
  function register(uint _tokenSaleId) external;
  function completeRegistration(uint _tokenSaleId) external;
  function redeem(uint _tokenSaleId, uint _amount) external;
  function withdraw(uint _tokenSaleId, uint _amount, address _for) external;
  function triggerUnwind(uint _tokenSaleId) external;
  function getTokenInsurance(uint _tokenSaleId) external;
}
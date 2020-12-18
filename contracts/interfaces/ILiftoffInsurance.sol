pragma solidity =0.6.6;

interface ILiftoffInsurance {
  function register(uint _tokenSaleId) external;
  function redeem(uint _tokenSaleId, uint _amount) external;
  function claim(uint _tokenSaleId) external;
  function createInsurance(uint _tokenSaleId) external;
}
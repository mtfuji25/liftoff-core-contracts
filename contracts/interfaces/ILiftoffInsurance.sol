pragma solidity 0.5.16;

interface ILiftoffInsurance {
  function requestRegistration(uint _tokenSaleId, uint xEthBuy) external;
  function completeRegistration(uint _tokenSaleId) external;
  function refund(address _token, uint _amount) external;
  function withdraw(address _token, uint _amount, address _for) external;
}
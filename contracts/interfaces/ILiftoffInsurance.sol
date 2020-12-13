pragma solidity 0.5.16;

interface ILiftoffInsurance {
  function acceptDeposit(address _token) external;
  function refund(address _token, uint _amount) external;
  function withdraw(address _token, uint _amount, address _for) external;
}
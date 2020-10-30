pragma solidity 0.5.16;

interface ILiftoffSwap {
  function acceptIgnite(address _token) payable external;
  function acceptSpark(address _token) payable external;
}
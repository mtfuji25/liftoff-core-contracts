pragma solidity =0.6.6;

interface ILiftoffSwap {
  function acceptIgnite(address _token) payable external;
  function acceptSpark(address _token) payable external;
}
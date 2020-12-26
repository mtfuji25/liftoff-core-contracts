pragma solidity =0.6.6;

interface ILiftoffSwap {
    function acceptIgnite(address _token) external payable;

    function acceptSpark(address _token) external payable;
}

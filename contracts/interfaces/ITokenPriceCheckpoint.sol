pragma solidity 0.5.16;

interface ITokenPriceCheckpoint{
  function getPriceAccumulatorAt(
    address pair,
    uint _block
  ) external view returns (uint priceAccumulator);
}
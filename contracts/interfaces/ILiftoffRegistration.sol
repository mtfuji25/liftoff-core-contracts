pragma solidity =0.6.6;

interface ILiftoffRegistration {
  function registerProject(
    string calldata ipfsHash,
    uint launchTime,
    uint softCap,
    uint hardCap,
    uint totalSupplyWad,
    string calldata name,
    string calldata symbol
  ) external;
}
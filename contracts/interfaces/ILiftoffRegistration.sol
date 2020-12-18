pragma solidity =0.6.6;

interface ILiftoffRegistration {
  function registerProject(
    string calldata ipfsProjectJsonHash,
    string calldata ipfsProjectLogoHash,
    string calldata ipfsProjectOpenGraphHash,
    uint launchTime,
    uint softCap,
    uint hardCap,
    uint totalSupplyWad,
    string calldata name,
    string calldata symbol
  ) external;
}
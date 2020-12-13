pragma solidity 0.5.16;

interface ILiftoffLauncher {
  function registerProject(
        string calldata ipfsProjectJsonHash,
        string calldata ipfsProjectLogoHash,
        string calldata ipfsProjectOpenGraphHash,
        uint launchTime
    ) external;
}
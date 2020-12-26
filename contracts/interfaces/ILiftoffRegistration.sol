pragma solidity =0.6.6;

interface ILiftoffRegistration {
    function registerProject(
        string calldata ipfsHash,
        uint256 launchTime,
        uint256 softCap,
        uint256 hardCap,
        uint256 totalSupplyWad,
        string calldata name,
        string calldata symbol
    ) external;
}

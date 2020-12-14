pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./SimpleToken.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./interfaces/ILiftoffRegistration.sol";

contract LiftoffRegistration is ILiftoffRegistration, Initializable, Ownable {
    struct ipfsProjectHash {
        string ipfsProjectJsonHash;
        string ipfsProjectLogoHash;
        string ipfsProjectOpenGraphHash;
    }

    ILiftoffEngine public liftoffEngine;
    uint public minLaunchTime;
    uint public maxLaunchTime;
    uint public softCapTimer;

    mapping(uint => ipfsProjectHash) tokenProjects;

    function initialize(
        address _owner,
        uint _minTimeToLaunch,
        uint _maxTimeToLaunch,
        uint _softCapTimer,
        ILiftoffEngine _liftoffEngine
    ) public initializer {
        Ownable.initialize(_owner);
        setLaunchTimeDelta(_minTimeToLaunch, _maxTimeToLaunch);
        setLiftoffEngine(_liftoffEngine);
        setSoftCapTimer(_softCapTimer);
    }

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
    ) external {
        require(launchTime >= block.timestamp + minLaunchTime, "Not allowed to launch before minLaunchTime");
        require(launchTime <= block.timestamp + maxLaunchTime, "Not allowed to launch after maxLaunchTime");
        require(totalSupplyWad < 10000000000000 ether, "Cannot launch more than 1 trillion tokens");      
        
        uint tokenId = liftoffEngine.launchToken(
            launchTime,
            launchTime + softCapTimer,
            softCap,
            hardCap,
            totalSupplyWad,
            name,
            symbol,
            msg.sender
        );

        ipfsProjectHash storage project = tokenProjects[tokenId];
        project.ipfsProjectJsonHash = ipfsProjectJsonHash;
        project.ipfsProjectLogoHash = ipfsProjectLogoHash;
        project.ipfsProjectOpenGraphHash = ipfsProjectOpenGraphHash;
    }

    function setSoftCapTimer(uint _seconds) public onlyOwner {
        softCapTimer = _seconds;
    }

    function setLaunchTimeDelta(uint _min, uint _max) public onlyOwner {
        minLaunchTime = _min;
        maxLaunchTime = _max;
    }

    function setLiftoffEngine(ILiftoffEngine _liftoffEngine) public onlyOwner {
        liftoffEngine = _liftoffEngine;
    }
}
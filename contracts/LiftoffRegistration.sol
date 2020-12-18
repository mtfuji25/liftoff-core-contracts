pragma solidity =0.6.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./interfaces/ILiftoffRegistration.sol";

contract LiftoffRegistration is ILiftoffRegistration, Initializable, OwnableUpgradeable {

    ILiftoffEngine public liftoffEngine;
    uint public minLaunchTime;
    uint public maxLaunchTime;
    uint public softCapTimer;

    tokenIpfsHashes[];

    function initialize(
        uint _minTimeToLaunch,
        uint _maxTimeToLaunch,
        uint _softCapTimer,
        ILiftoffEngine _liftoffEngine
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        setLaunchTimeDelta(_minTimeToLaunch, _maxTimeToLaunch);
        setLiftoffEngine(_liftoffEngine);
        setSoftCapTimer(_softCapTimer);
    }

    function registerProject(
        string calldata ipfsHash,
        uint launchTime,
        uint softCap,
        uint hardCap,
        uint totalSupplyWad,
        string calldata name,
        string calldata symbol
    ) external override {
        require(launchTime >= block.timestamp + minLaunchTime, "Not allowed to launch before minLaunchTime");
        require(launchTime <= block.timestamp + maxLaunchTime, "Not allowed to launch after maxLaunchTime");
        require(totalSupplyWad < 10^12, "Cannot launch more than 1 trillion tokens");      

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
        
        tokenIpfsHashes[tokenId] = ipfsHash;
    }

    function setSoftCapTimer(uint _seconds) public onlyOwner {
        softCapTimer = _seconds;
    }

    function setLaunchTimeWindow(uint _min, uint _max) public onlyOwner {
        minLaunchTime = _min;
        maxLaunchTime = _max;
    }

    function setLiftoffEngine(ILiftoffEngine _liftoffEngine) public onlyOwner {
        liftoffEngine = _liftoffEngine;
    }
}
pragma solidity =0.6.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./interfaces/ILiftoffRegistration.sol";

contract LiftoffRegistration is
    ILiftoffRegistration,
    Initializable,
    OwnableUpgradeable
{
    ILiftoffEngine public liftoffEngine;
    uint256 public minLaunchTime;
    uint256 public maxLaunchTime;
    uint256 public softCapTimer;

    string[] tokenIpfsHashes;

    event TokenIpfsHash(uint256 tokenId, string ipfsHash);

    function initialize(
        uint256 _minTimeToLaunch,
        uint256 _maxTimeToLaunch,
        uint256 _softCapTimer,
        ILiftoffEngine _liftoffEngine
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        setLaunchTimeWindow(_minTimeToLaunch, _maxTimeToLaunch);
        setLiftoffEngine(_liftoffEngine);
        setSoftCapTimer(_softCapTimer);
    }

    function registerProject(
        string calldata ipfsHash,
        uint256 launchTime,
        uint256 softCap,
        uint256 hardCap,
        uint256 totalSupplyWad,
        string calldata name,
        string calldata symbol
    ) external override {
        require(
            launchTime >= block.timestamp + minLaunchTime,
            "Not allowed to launch before minLaunchTime"
        );
        require(
            launchTime <= block.timestamp + maxLaunchTime,
            "Not allowed to launch after maxLaunchTime"
        );
        require(
            totalSupplyWad < (10**12) * (10**18),
            "Cannot launch more than 1 trillion tokens"
        );

        uint256 tokenId =
            liftoffEngine.launchToken(
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

        emit TokenIpfsHash(tokenId, ipfsHash);
    }

    function setSoftCapTimer(uint256 _seconds) public onlyOwner {
        softCapTimer = _seconds;
    }

    function setLaunchTimeWindow(uint256 _min, uint256 _max) public onlyOwner {
        minLaunchTime = _min;
        maxLaunchTime = _max;
    }

    function setLiftoffEngine(ILiftoffEngine _liftoffEngine) public onlyOwner {
        liftoffEngine = _liftoffEngine;
    }
}
